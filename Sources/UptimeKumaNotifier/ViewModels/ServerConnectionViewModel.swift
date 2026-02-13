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

    /// Initialize with existing monitor data (used during refresh)
    convenience init(server: Server, existingMonitors: [Int: Monitor]) {
        self.init(server: server)
        self.monitors = existingMonitors
        // If we have existing monitors, consider the connection as refreshing
        if !existingMonitors.isEmpty {
            self.connectionState = .refreshing
        }
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
            connectWithPassword(service: service, password: password)
        } else {
            connectionState = .error("No credentials found")
        }
    }

    /// Connect using password, generating a live TOTP code if a 2FA secret is stored.
    private func connectWithPassword(service: SocketIOService, password: String) {
        let twoFactorSecret = (try? KeychainService.getTwoFactorToken(for: server.id)) ?? nil

        if let secret = twoFactorSecret, !secret.isEmpty {
            if let code = TOTPService.generateCode(secret: secret) {
                service.connectWithTwoFactor(password: password, twoFactorToken: code)
            } else {
                connectionState = .error("Invalid 2FA secret — could not generate code")
            }
        } else {
            service.connect(password: password)
        }
    }

    func submitTwoFactorCode(_ code: String) {
        socketService?.submitTwoFactorCode(code)
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

    func socketServiceTokenAuthFailed(_ service: SocketIOService) {
        // Stale JWT token — clear it and reconnect with password
        try? KeychainService.deleteToken(for: server.id)
        service.disconnect()

        guard let password = (try? KeychainService.getPassword(for: server.id)) ?? nil else {
            connectionState = .error("Token expired and no password available")
            return
        }

        let newService = SocketIOService(server: server, delegate: self)
        self.socketService = newService
        connectWithPassword(service: newService, password: password)
    }

    func socketService(_ service: SocketIOService, didReceiveMonitorList newMonitors: [Int: Monitor]) {
        // Merge with existing data: preserve known statuses and heartbeats
        // since monitorList only contains metadata, not current heartbeat status
        var merged = newMonitors
        for (id, existing) in monitors {
            if var monitor = merged[id] {
                // Keep the existing status/heartbeat if the new one is just .pending (default)
                if monitor.status == .pending && existing.status != .pending {
                    monitor.status = existing.status
                    monitor.latestHeartbeat = existing.latestHeartbeat
                }
                merged[id] = monitor
            }
        }
        monitors = merged
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
