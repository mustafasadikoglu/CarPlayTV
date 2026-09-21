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
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.player = AVPlayer()
        setupAudioSession()
        setupRemoteCommands()
        setupPlayerObservers()
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
    }

    // MARK: - Playback Control
    public func play(channel: Channel) {
        self.currentChannel = channel
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
        playerItem.preferredForwardBufferDuration = 5.0 // Low latency for in-car live streams
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false

        // Observe player item status
        statusObserver?.invalidate()
        statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.isBuffering = false
                    self?.isPlaying = true
                case .failed:
                    self?.isBuffering = false
                    self?.isPlaying = false
                    self?.playbackError = item.error?.localizedDescription ?? "Akış oynatılamadı"
                default:
                    break
                }
            }
        }

        player.replaceCurrentItem(with: playerItem)
        player.play()
        self.isPlaying = true

        updateNowPlayingInfo()
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
            // Attempt auto-recovery
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

    // MARK: - Now Playing Info & Remote Command Center
    private func updateNowPlayingInfo() {
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
            // Load artwork asynchronously
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
