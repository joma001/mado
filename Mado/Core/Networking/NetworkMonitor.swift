import Foundation
import Network
import os

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mado.networkmonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.connectionType = Self.resolveConnectionType(path)

                if !wasConnected && self.isConnected {
                    MadoLogger.sync.info("Network restored (\(String(describing: self.connectionType)))")
                    self.onReconnect?()
                } else if wasConnected && !self.isConnected {
                    MadoLogger.sync.info("Network lost")
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Called when connectivity transitions from offline to online.
    var onReconnect: (() -> Void)?

    private static func resolveConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        return .unknown
    }
}
