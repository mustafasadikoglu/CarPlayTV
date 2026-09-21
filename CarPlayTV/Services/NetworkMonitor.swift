import Foundation
import Network
import Combine

extension Notification.Name {
    public static let networkRestored = Notification.Name("carplaytv_network_restored")
}

public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()

    @Published public private(set) var isConnected: Bool = true
    @Published public private(set) var isCellular: Bool = false
    @Published public private(set) var isExpensive: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "carplaytv.network.monitor")
    private var wasConnected: Bool = true

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let connected = (path.status == .satisfied)
            let cellular = path.usesInterfaceType(.cellular)
            let expensive = path.isExpensive

            DispatchQueue.main.async {
                let previouslyDisconnected = !self.wasConnected
                self.isConnected = connected
                self.isCellular = cellular
                self.isExpensive = expensive
                self.wasConnected = connected

                // If internet just came back after being down, notify subscribers
                if previouslyDisconnected && connected {
                    print("CarPlayTV: Network restored! Resuming live streams...")
                    NotificationCenter.default.post(name: .networkRestored, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
