import Foundation

@Observable
@MainActor
final class ServerConnectionViewModel: SocketIOServiceDelegate {
    let server: Server
    var connectionState: ServerConnectionState = .disconnected
    var monitors: [Int: Monitor] = [:]

    private var socketService: SocketIOService?

    init(server: Server) {
        self.server = server
    }

    var upCount: Int {
        monitors.values.filter { $0.active && $0.status == .up }.count
    }

    var downCount: Int {
        monitors.values.filter { $0.active && $0.status == .down }.count
    }

    var pendingCount: Int {
        monitors.values.filter { $0.active && $0.status == .pending }.count
    }

    var maintenanceCount: Int {
        monitors.values.filter { $0.active && $0.status == .maintenance }.count
    }

    var sortedMonitors: [Monitor] {
        monitors.values
            .filter { $0.active }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status.rawValue < rhs.status.rawValue
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func connect() {
        let service = SocketIOService(server: server, delegate: self)
        self.socketService = service

        // Try token-based reconnection first, fall back to password
        let token = (try? KeychainService.getToken(for: server.id)) ?? nil
        let password = (try? KeychainService.getPassword(for: server.id)) ?? nil

        if let token, let password {
            service.connectWithToken(token, password: password)
        } else if let password {
            service.connect(password: password)
        } else {
            connectionState = .error("No credentials found")
        }
    }

    func disconnect() {
        socketService?.disconnect()
        socketService = nil
        connectionState = .disconnected
        monitors = [:]
    }

    // MARK: - SocketIOServiceDelegate

    func socketService(_ service: SocketIOService, didChangeState state: ServerConnectionState) {
        connectionState = state

        // If auth failed, clear token so next attempt uses password
        if case .error = state {
            try? KeychainService.deleteToken(for: server.id)
        }
    }

    func socketService(_ service: SocketIOService, didReceiveMonitorList newMonitors: [Int: Monitor]) {
        monitors = newMonitors
    }

    func socketService(_ service: SocketIOService, didReceiveHeartbeat heartbeat: Heartbeat) {
        guard var monitor = monitors[heartbeat.monitorID] else { return }

        let oldStatus = monitor.status
        let newStatus = heartbeat.status

        monitor.status = newStatus
        monitor.latestHeartbeat = heartbeat
        monitors[heartbeat.monitorID] = monitor

        if oldStatus != newStatus {
            NotificationService.sendStatusChange(
                monitorName: monitor.name,
                serverName: server.name,
                oldStatus: oldStatus,
                newStatus: newStatus
            )
        }
    }
}
