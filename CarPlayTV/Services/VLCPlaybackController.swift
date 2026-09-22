import Foundation
import VLCKit
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

    public let player = VLCMediaPlayer()

    private var pollTimer: Timer?

    private init() {}

    /// Verilen URL'i oynatmaya başlar. `startTime` saniye cinsinden kaldığı yerden devam içindir.
    public func play(url: URL, startTime: Double = 0) {
        stop()

        isPlaying = false
        currentTime = 0
        duration = 0
        isBuffering = true
        errorMessage = nil

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

        if let time = p.time {
            currentTime = time.value.doubleValue / 1000.0
        }

        if let length = p.media?.length, length.value.doubleValue > 0 {
            duration = length.value.doubleValue / 1000.0
        } else if let time = p.time, let remaining = p.remainingTime {
            let total = time.value.doubleValue + remaining.value.doubleValue
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
    }
}
