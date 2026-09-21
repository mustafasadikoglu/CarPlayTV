import UIKit
import CarPlay

public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    public var interfaceController: CPInterfaceController?

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        PlaybackManager.shared.isCarPlayConnected = true

        CarPlayInterfaceManager.shared.setInterfaceController(interfaceController)

        // Check if external video window needs initialization
        if PlaybackManager.shared.carPlayVideoMode == .forceExternalWindow {
            CarPlayVideoWindowController.shared.checkAndAttachExternalVideo()
        }

        print("CarPlayTV: Connected to CarPlay scene")
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        PlaybackManager.shared.isCarPlayConnected = false

        CarPlayInterfaceManager.shared.clearInterfaceController()
        CarPlayVideoWindowController.shared.tearDownExternalWindow()

        print("CarPlayTV: Disconnected from CarPlay scene")
    }
}
