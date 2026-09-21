import UIKit
import AVFoundation

public final class CarPlayVideoWindowController {
    public static let shared = CarPlayVideoWindowController()

    private var externalWindow: UIWindow?
    private var playerLayer: AVPlayerLayer?

    private init() {
        setupScreenNotifications()
    }

    private func setupScreenNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidConnect(notification:)),
            name: UIScreen.didConnectNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidDisconnect(notification:)),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
    }

    @objc private func screenDidConnect(notification: Notification) {
        guard let newScreen = notification.object as? UIScreen else { return }
        checkAndAttachExternalVideo(on: newScreen)
    }

    @objc private func screenDidDisconnect(notification: Notification) {
        tearDownExternalWindow()
    }

    public func checkAndAttachExternalVideo(on screen: UIScreen? = nil) {
        // If mode is set to forceExternalWindow or if external screens are detected
        guard PlaybackManager.shared.carPlayVideoMode == .forceExternalWindow else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let targetScreen = screen ?? UIScreen.screens.first(where: { $0 != UIScreen.main })
            guard let externalScreen = targetScreen else { return }

            // Create window on external screen
            let window = UIWindow(frame: externalScreen.bounds)
            window.screen = externalScreen
            window.backgroundColor = .black

            let viewController = UIViewController()
            viewController.view.backgroundColor = .black

            let layer = AVPlayerLayer(player: PlaybackManager.shared.player)
            layer.frame = externalScreen.bounds
            layer.videoGravity = PlaybackManager.shared.aspectRatio.gravity
            viewController.view.layer.addSublayer(layer)

            window.rootViewController = viewController
            window.isHidden = false

            self.externalWindow = window
            self.playerLayer = layer
            PlaybackManager.shared.isExternalVideoActive = true

            print("CarPlayTV: External video window successfully created on \(externalScreen.bounds.size)")
        }
    }

    public func updateAspectRatio(_ ratio: VideoAspectRatio) {
        playerLayer?.videoGravity = ratio.gravity
    }

    public func tearDownExternalWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.playerLayer?.removeFromSuperlayer()
            self?.playerLayer = nil
            self?.externalWindow?.isHidden = true
            self?.externalWindow = nil
            PlaybackManager.shared.isExternalVideoActive = false
            print("CarPlayTV: External video window torn down")
        }
    }
}
