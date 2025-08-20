//
//  NWPathMonitor.swift
//  Stakehub
//
//  Created by Stakehub Dev on 18/08/25.
//

// NetworkMonitor.swift
import Network
import Foundation

final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "net.monitor")

    @Published private(set) var isOnline: Bool = true

    private init() {
            monitor.pathUpdateHandler = { [weak self] path in
                let online = (path.status == .satisfied)
                DispatchQueue.main.async {
                    self?.isOnline = online
                    NotificationCenter.default.post(
                        name: .networkStatusChanged,
                        object: online
                    )
                }
            }
            monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("StakehubNetworkStatusChanged")
}
