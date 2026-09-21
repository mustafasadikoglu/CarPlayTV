import SwiftUI
import AVFoundation
import AVKit

public struct CustomVideoPlayerView: UIViewControllerRepresentable {
    @ObservedObject var playbackManager = PlaybackManager.shared

    public init() {}

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = playbackManager.player
        controller.showsPlaybackControls = false
        controller.videoGravity = playbackManager.aspectRatio.gravity
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = false
        controller.view.backgroundColor = .black
        return controller
    }

    public func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== playbackManager.player {
            controller.player = playbackManager.player
        }
        if controller.videoGravity != playbackManager.aspectRatio.gravity {
            controller.videoGravity = playbackManager.aspectRatio.gravity
        }
    }
}

public final class PlayerViewController: UIViewController {
    private var playerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?
    public var player: AVPlayer? {
        didSet {
            playerLayer?.player = player
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLayer()
        setupPiP()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    private func setupLayer() {
        if playerLayer == nil {
            let layer = AVPlayerLayer(player: player)
            layer.frame = view.bounds
            layer.videoGravity = .resizeAspect
            view.layer.addSublayer(layer)
            self.playerLayer = layer
        } else {
            playerLayer?.player = player
        }
    }

    private func setupPiP() {
        guard let layer = playerLayer, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        pipController = AVPictureInPictureController(playerLayer: layer)
    }

    public func setPlayer(_ player: AVPlayer) {
        self.player = player
        if playerLayer == nil {
            setupLayer()
        } else {
            playerLayer?.player = player
        }
    }

    public func setVideoGravity(_ gravity: AVLayerVideoGravity) {
        playerLayer?.videoGravity = gravity
    }

    public func startPictureInPicture() {
        pipController?.startPictureInPicture()
    }
}

