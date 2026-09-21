import UIKit
import CarPlay

public class AppDelegate: UIResponder, UIApplicationDelegate {

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize singletons
        _ = NetworkMonitor.shared
        _ = PlaybackManager.shared
        _ = PlaylistStore.shared
        _ = VODStore.shared
        _ = ImageCacheManager.shared
        _ = KeychainHelper.shared
        _ = EPGStore.shared
        _ = CarPlayVideoWindowController.shared
        return true
    }

    // MARK: - UISceneSession Lifecycle
    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == UISceneSession.Role(rawValue: "CPTemplateApplicationSceneSessionRoleApplication") {
            let config = UISceneConfiguration(
                name: "CarPlay Configuration",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        } else {
            let config = UISceneConfiguration(
                name: "Default Configuration",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = SceneDelegate.self
            return config
        }
    }

    public func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}
}
