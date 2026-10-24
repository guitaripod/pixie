import Foundation
import Network

protocol NetworkMonitorProtocol {
    var isConnected: Bool { get }
    var isExpensive: Bool { get }
    var connectionType: NetworkMonitor.ConnectionType { get }
    
    func startMonitoring()
    func stopMonitoring()
}

class NetworkMonitor: NetworkMonitorProtocol {
    static let shared = NetworkMonitor()
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case none
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.guitaripod.pixie.networkmonitor")
    
    private(set) var isConnected: Bool = true
    private(set) var isExpensive: Bool = false
    private(set) var connectionType: ConnectionType = .unknown
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    private func updateConnectionStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        connectionType = getConnectionType(from: path)

        NotificationCenter.default.post(
            name: .networkStatusChanged,
            object: self,
            userInfo: [
                "isConnected": isConnected,
                "isExpensive": isExpensive,
                "connectionType": connectionType
            ]
        )
    }
    
    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.status == .unsatisfied {
            return .none
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("NetworkStatusChanged")
}