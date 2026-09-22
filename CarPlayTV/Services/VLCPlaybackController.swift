import Foundation
import MobileVLCKit
import Combine

/// AVPlayer'ın oynatamadığı MKV/AVI içerikleri MobileVLCKit üzerinden oynatan denetleyici.
/// Durum bilgileri `@Published` olarak yayınlanır ve PlaybackManager bu değerleri aynalar.
public final class VLCPlaybackController: ObservableObject {
    public static let shared = VLCPlaybackController()

    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var isBuffering: Bool = false
    @Published public var errorMessage: String?
    @Published public var playbackRate: Float = 1.0
    @Published public var subtitleTracks: [String] = []
    @Published public var audioTracks: [String] = []
    @Published public var currentSubtitleIndex: Int = -1
    @Published public var currentAudioIndex: Int = -1

    public let player: VLCMediaPlayer

    private var pollTimer: Timer?

    private init() {
        self.player = VLCMediaPlayer(options: [])
    }

    /// Verilen URL'i oynatmaya başlar. `startTime` saniye cinsinden kaldığı yerden devam içindir.
    public func play(url: URL, startTime: Double = 0) {
        stop()

        isPlaying = false
        currentTime = 0
        duration = 0
        isBuffering = true
        errorMessage = nil
        playbackRate = 1.0
        player.rate = 1.0
        subtitleTracks = []
        audioTracks = []
        currentSubtitleIndex = -1
        currentAudioIndex = -1

        let media = VLCMedia(url: url)
        media.addOption(":network-caching=2000")
        media.addOption(":clock-synchronization=0")
        media.addOption(":avcodec-hw=any")
        player.media = media
        player.play()

        if startTime > 1 {
            // Medya hazırlandıktan sonra konuma atla.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                if self.duration > 1 {
                    let target = min(max(startTime / self.duration, 0), 0.99)
                    self.player.position = Float(target)
                }
            }
        }

        startPolling()
    }

    public func togglePlayPause() {
        if player.isPlaying {
            pause()
        } else {
            resume()
        }
    }

    public func pause() {
        player.pause()
        isPlaying = false
    }

    public func resume() {
        player.play()
        isPlaying = true
    }

    public func seek(to seconds: Double) {
        let total = duration > 0 ? duration : 1
        let clamped = max(0, min(seconds, total))
        player.position = Float(clamped / total)
        currentTime = clamped
    }

    public func setRate(_ rate: Float) {
        player.rate = rate
        playbackRate = rate
    }

    public func cycleSubtitle() {
        let indexes = player.videoSubTitlesIndexes.compactMap { ($0 as? NSNumber)?.intValue }.map { Int($0) }
        guard !indexes.isEmpty else { return }
        let current = Int(player.currentVideoSubTitleIndex)
        if let idx = indexes.firstIndex(of: current) {
            if idx + 1 < indexes.count {
                player.currentVideoSubTitleIndex = Int32(indexes[idx + 1])
            } else {
                player.currentVideoSubTitleIndex = -1
            }
        } else {
            player.currentVideoSubTitleIndex = Int32(indexes[0])
        }
        refreshTracks()
    }

    public func cycleAudioTrack() {
        let indexes = player.audioTrackIndexes.compactMap { ($0 as? NSNumber)?.intValue }.map { Int($0) }
        guard !indexes.isEmpty else { return }
        let current = Int(player.currentAudioTrackIndex)
        if let idx = indexes.firstIndex(of: current) {
            player.currentAudioTrackIndex = Int32(indexes[(idx + 1) % indexes.count])
        } else {
            player.currentAudioTrackIndex = Int32(indexes[0])
        }
        refreshTracks()
    }

    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        player.stop()
        isPlaying = false
        isBuffering = false
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }

    private func refreshState() {
        let p = player

        isPlaying = p.isPlaying
        currentTime = (p.time.value?.doubleValue ?? 0) / 1000.0

        if let length = p.media?.length {
            let total = length.value?.doubleValue ?? 0
            if total > 0 {
                duration = total / 1000.0
            }
        } else {
            let total = (p.time.value?.doubleValue ?? 0) + (p.remainingTime?.value?.doubleValue ?? 0)
            if total > 0 {
                duration = total / 1000.0
            }
        }

        switch p.state {
        case .buffering, .opening:
            isBuffering = true
        case .playing:
            isBuffering = false
        case .error:
            isBuffering = false
            errorMessage = "Video oynatılamadı (VLC hatası)"
        case .ended:
            isBuffering = false
        default:
            break
        }

        refreshTracks()
    }

    private func refreshTracks() {
        subtitleTracks = player.videoSubTitlesNames.compactMap { $0 as? String }
        audioTracks = player.audioTrackNames.compactMap { $0 as? String }
        currentSubtitleIndex = Int(player.currentVideoSubTitleIndex)
        currentAudioIndex = Int(player.currentAudioTrackIndex)
    }
}
