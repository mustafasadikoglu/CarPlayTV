import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

public enum VideoAspectRatio: String, CaseIterable {
    case fit = "Sığdır"
    case fill = "Doldur"
    case sixteenByNine = "16:9"
    case fourByThree = "4:3"

    public var gravity: AVLayerVideoGravity {
        switch self {
        case .fit: return .resizeAspect
        case .fill: return .resizeAspectFill
        case .sixteenByNine, .fourByThree: return .resize
        }
    }
}

public enum CarPlayVideoMode: String, CaseIterable, Codable {
    case autoParkAirPlay = "AirPlay / Park Halinde Video"
    case forceExternalWindow = "Doğrudan Harici Pencere (Sideload/TrollStore)"
    case companionAudioOnly = "Çift Ekran (CarPlay Ses + Telefon Video)"
}

public final class PlaybackManager: ObservableObject {
    public static let shared = PlaybackManager()

    @Published public var player: AVPlayer
    @Published public var currentChannel: Channel?
    @Published public var currentVODItem: VODItem?
    @Published public var isLiveStream: Bool = true
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var isPlaying: Bool = false
    @Published public var isBuffering: Bool = false
    @Published public var aspectRatio: VideoAspectRatio = .fit
    @Published public var isCarPlayConnected: Bool = false
    @Published public var isExternalVideoActive: Bool = false
    @Published public var carPlayVideoMode: CarPlayVideoMode = .autoParkAirPlay
    @Published public var volume: Float = 1.0
    @Published public var playbackError: String?

    private var timeObserverToken: Any?
    private var statusObserver: NSKeyValueObservation?
    private var externalPlaybackObserver: NSKeyValueObservation?
    private var bufferExpansionWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.player = AVPlayer()
        setupAudioSession()
        setupRemoteCommands()
        setupPlayerObservers()
        setupTimeObserver()
        _ = NetworkMonitor.shared
        loadSavedSettings()
    }

    // MARK: - Audio Session
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            print("CarPlayTV: AVAudioSession error: \(error.localizedDescription)")
        }
    }

    private func setupPlayerObservers() {
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true

        externalPlaybackObserver = player.observe(\.isExternalPlaybackActive, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isExternalVideoActive = player.isExternalPlaybackActive
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemFailed),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkRestored),
            name: .networkRestored,
            object: nil
        )
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isLiveStream else { return }

            let currentSec = CMTimeGetSeconds(time)
            if !currentSec.isNaN && !currentSec.isInfinite {
                self.currentTime = currentSec
            }

            if let item = self.player.currentItem {
                let durationSec = CMTimeGetSeconds(item.duration)
                if !durationSec.isNaN && !durationSec.isInfinite && durationSec > 0 {
                    self.duration = durationSec
                }
            }

            // Periodically save progress to VODStore every 5 seconds
            if let vod = self.currentVODItem, self.duration > 0, Int(self.currentTime) % 5 == 0 {
                VODStore.shared.saveProgress(for: vod, position: self.currentTime, duration: self.duration)
            }
        }
    }

    // MARK: - Playback Control
    public func play(channel: Channel) {
        // Fast Zapping: Cancel previous downloads and reset work item
        bufferExpansionWorkItem?.cancel()
        bufferExpansionWorkItem = nil
        (player.currentItem?.asset as? AVURLAsset)?.cancelLoading()
        player.replaceCurrentItem(with: nil)

        self.isLiveStream = true
        self.currentChannel = channel
        self.currentVODItem = nil
        self.currentTime = 0
        self.duration = 0
        self.isBuffering = true
        self.playbackError = nil

        PlaylistStore.shared.recordRecent(channel: channel)

        // Configure asset with headers if present
        let asset: AVURLAsset
        if let userAgent = channel.httpUserAgent {
            let headers = ["User-Agent": userAgent]
            asset = AVURLAsset(url: channel.streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        } else {
            asset = AVURLAsset(url: channel.streamURL)
        }

        let playerItem = AVPlayerItem(asset: asset)
        // Stage 1: Ultra fast startup buffer (< 1s latency)
        playerItem.preferredForwardBufferDuration = 1.0
        playerItem.automaticallyPreservesTimeOffsetFromLive = true
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false

        observePlayerItem(playerItem)

        player.replaceCurrentItem(with: playerItem)
        player.play()
        self.isPlaying = true

        // Stage 2: Smoothly expand buffer to 6.0s after 4.0s for in-car cellular driving stability
        let expansionItem = DispatchWorkItem { [weak playerItem] in
            playerItem?.preferredForwardBufferDuration = 6.0
            print("CarPlayTV: Fast zapping complete. Buffer expanded to 6.0s for driving stability.")
        }
        self.bufferExpansionWorkItem = expansionItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: expansionItem)

        updateNowPlayingInfo()
    }

    public func playVOD(item: VODItem, startFromBeginning: Bool = false) {
        bufferExpansionWorkItem?.cancel()
        bufferExpansionWorkItem = nil
        (player.currentItem?.asset as? AVURLAsset)?.cancelLoading()
        player.replaceCurrentItem(with: nil)

        self.isLiveStream = false
        self.currentVODItem = item
        self.currentChannel = nil
        self.currentTime = startFromBeginning ? 0 : item.lastPosition
        self.duration = item.duration
        self.isBuffering = true
        self.playbackError = nil

        let playerItem = AVPlayerItem(url: item.streamURL)
        playerItem.preferredForwardBufferDuration = 2.0
        observePlayerItem(playerItem)

        player.replaceCurrentItem(with: playerItem)

        if !startFromBeginning && item.lastPosition > 5 {
            let targetTime = CMTime(seconds: item.lastPosition, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        player.play()
        self.isPlaying = true

        updateNowPlayingInfo()
    }

    private func observePlayerItem(_ playerItem: AVPlayerItem) {
        statusObserver?.invalidate()
        statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.isBuffering = false
                    self?.isPlaying = true
                    if let dur = self?.player.currentItem?.duration {
                        let sec = CMTimeGetSeconds(dur)
                        if !sec.isNaN && !sec.isInfinite && sec > 0 {
                            self?.duration = sec
                        }
                    }
                case .failed:
                    self?.isBuffering = false
                    self?.isPlaying = false
                    self?.playbackError = item.error?.localizedDescription ?? "Yayın oynatılamadı"
                default:
                    break
                }
            }
        }
    }

    public func seek(to seconds: Double) {
        guard !isLiveStream else { return }
        let clamped = max(0, min(seconds, duration))
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        self.currentTime = clamped
        updateNowPlayingInfo()

        if let vod = currentVODItem {
            VODStore.shared.saveProgress(for: vod, position: clamped, duration: duration)
        }
    }

    public func skipForward(seconds: Double = 10) {
        seek(to: currentTime + seconds)
    }

    public func skipBackward(seconds: Double = 10) {
        seek(to: currentTime - seconds)
    }

    public func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    public func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    public func resume() {
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    public func playNextChannel() {
        guard let current = currentChannel else { return }
        let channels = PlaylistStore.shared.channels
        if let idx = channels.firstIndex(where: { $0.id == current.id }) {
            let nextIdx = (idx + 1) % channels.count
            play(channel: channels[nextIdx])
        }
    }

    public func playPreviousChannel() {
        guard let current = currentChannel else { return }
        let channels = PlaylistStore.shared.channels
        if let idx = channels.firstIndex(where: { $0.id == current.id }) {
            let prevIdx = (idx - 1 + channels.count) % channels.count
            play(channel: channels[prevIdx])
        }
    }

    @objc private func handleItemStalled() {
        DispatchQueue.main.async {
            self.isBuffering = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if self?.isPlaying == true {
                    self?.player.play()
                }
            }
        }
    }

    @objc private func handleItemFailed() {
        DispatchQueue.main.async {
            self.playbackError = "Bağlantı kesildi, yeniden deneniyor..."
            if let channel = self.currentChannel {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.play(channel: channel)
                }
            }
        }
    }

    @objc private func handleNetworkRestored() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("CarPlayTV: Network restored. Auto-recovering playback...")
            if let channel = self.currentChannel, (!self.isPlaying || self.playbackError != nil) {
                self.play(channel: channel)
            } else if let vod = self.currentVODItem, (!self.isPlaying || self.playbackError != nil) {
                self.playVOD(item: vod, startFromBeginning: false)
            }
        }
    }


    // MARK: - Now Playing Info & Remote Command Center
    private func updateNowPlayingInfo() {
        if isLiveStream {
            guard let channel = currentChannel else {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                return
            }

            var nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyTitle: channel.name,
                MPMediaItemPropertyArtist: "CarPlayTV - \(channel.groupTitle)",
                MPNowPlayingInfoPropertyIsLiveStream: true,
                MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
            ]

            if let logoUrl = channel.logoURL {
                URLSession.shared.dataTask(with: logoUrl) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        DispatchQueue.main.async {
                            var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? nowPlayingInfo
                            currentInfo[MPMediaItemPropertyArtwork] = artwork
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                        }
                    }
                }.resume()
            }

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        } else {
            guard let vod = currentVODItem else {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                return
            }

            var nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyTitle: vod.title,
                MPMediaItemPropertyArtist: "CarPlayTV - \(vod.categoryName)",
                MPNowPlayingInfoPropertyIsLiveStream: false,
                MPMediaItemPropertyPlaybackDuration: duration,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
                MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
            ]

            if let poster = vod.posterURL {
                URLSession.shared.dataTask(with: poster) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        DispatchQueue.main.async {
                            var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? nowPlayingInfo
                            currentInfo[MPMediaItemPropertyArtwork] = artwork
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                        }
                    }
                }.resume()
            }

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNextChannel()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPreviousChannel()
            return .success
        }

        // VOD Skip Commands for CarPlay & Lock Screen
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward(seconds: 10)
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward(seconds: 10)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: posEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }


    public func setCarPlayVideoMode(_ mode: CarPlayVideoMode) {
        self.carPlayVideoMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "carplay_video_mode")

        switch mode {
        case .autoParkAirPlay:
            player.allowsExternalPlayback = true
            player.usesExternalPlaybackWhileExternalScreenIsActive = true
        case .forceExternalWindow:
            player.allowsExternalPlayback = false
            player.usesExternalPlaybackWhileExternalScreenIsActive = false
            // Will route video layer to CarPlayVideoWindowController
        case .companionAudioOnly:
            player.allowsExternalPlayback = false
            player.usesExternalPlaybackWhileExternalScreenIsActive = false
        }
    }

    private func loadSavedSettings() {
        if let raw = UserDefaults.standard.string(forKey: "carplay_video_mode"),
           let mode = CarPlayVideoMode(rawValue: raw) {
            setCarPlayVideoMode(mode)
        }
    }
}
