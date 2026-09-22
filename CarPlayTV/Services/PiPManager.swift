import AVFoundation
import AVKit
import UIKit
import Combine

/// AVPlayer için Resim içinde Resim (PiP) denetleyicisi.
final class PiPManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    static let shared = PiPManager()

    @Published var isActive: Bool = false

    private var pipController: AVPictureInPictureController?
    private var playerLayer: AVPlayerLayer?
    private let hostView = UIView()

    var isSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    private override init() {
        super.init()
        hostView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        hostView.backgroundColor = .clear
        hostView.isUserInteractionEnabled = false
    }

    func start(player: AVPlayer, gravity: AVLayerVideoGravity) {
        guard isSupported else { return }

        if pipController == nil {
            let layer = AVPlayerLayer(player: player)
            layer.frame = hostView.bounds
            layer.videoGravity = gravity
            playerLayer = layer
            hostView.layer.addSublayer(layer)

            let controller = AVPictureInPictureController(playerLayer: layer)
            controller.delegate = self
            pipController = controller
        }

        if hostView.superview == nil, let window = Self.keyWindow() {
            window.addSubview(hostView)
        }

        pipController?.startPictureInPicture()
    }

    func stop() {
        pipController?.stopPictureInPicture()
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    // MARK: AVPictureInPictureControllerDelegate
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = true
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isActive = false
    }
}
