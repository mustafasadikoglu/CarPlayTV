import SwiftUI
import AVFoundation
import AVKit

public struct CustomVideoPlayerView: UIViewControllerRepresentable {
    @ObservedObject var playbackManager = PlaybackManager.shared

    public init() {}

    public func makeUIViewController(context: Context) -> PlayerViewController {
        let controller = PlayerViewController()
        controller.setPlayer(playbackManager.player)
        controller.setVideoGravity(playbackManager.aspectRatio.gravity)
        return controller
    }

    public func updateUIViewController(_ uiViewController: PlayerViewController, context: Context) {
        uiViewController.setVideoGravity(playbackManager.aspectRatio.gravity)
        // Ensure player instance is linked
        if uiViewController.player != playbackManager.player {
            uiViewController.setPlayer(playbackManager.player)
        }
    }
}

public final class PlayerViewController: UIViewController {
    private var playerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?
    public private(set) var player: AVPlayer?

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
        let layer = AVPlayerLayer()
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspect
        view.layer.addSublayer(layer)
        self.playerLayer = layer
    }

    private func setupPiP() {
        guard let layer = playerLayer, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        pipController = AVPictureInPictureController(playerLayer: layer)
    }

    public func setPlayer(_ player: AVPlayer) {
        self.player = player
        playerLayer?.player = player
    }

    public func setVideoGravity(_ gravity: AVLayerVideoGravity) {
        playerLayer?.videoGravity = gravity
    }

    public func startPictureInPicture() {
        pipController?.startPictureInPicture()
    }
}
