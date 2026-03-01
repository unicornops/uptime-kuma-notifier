import Foundation

@Observable
@MainActor
final class ServerConnectionViewModel: SocketIOServiceDelegate {
    let server: Server
    var connectionState: ServerConnectionState = .disconnected
    var monitors: [Int: Monitor] = [:]

    private var socketService: SocketIOService?
    private var lastDataReceivedDate: Date?
    private var connectionStartDate: Date?
    private var watchdogTask: Task<Void, Never>?

    private static let staleConnectionTimeout: TimeInterval = 180  // 3 minutes
    private static let watchdogCheckInterval: TimeInterval = 60    // Check every minute

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
        lastDataReceivedDate = nil
        connectionStartDate = nil
        socketService?.disconnect()
        socketService = nil
        startConnection()
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

    /// Creates a new SocketIOService and initiates a connection using stored credentials.
    private func startConnection() {
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

    func submitTwoFactorCode(_ code: String) {
        socketService?.submitTwoFactorCode(code)
    }

    func disconnect() {
        stopWatchdog()
        lastDataReceivedDate = nil
        connectionStartDate = nil
        socketService?.disconnect()
        socketService = nil
        connectionState = .disconnected
        monitors = [:]
    }

    // MARK: - SocketIOServiceDelegate

    func socketService(_ service: SocketIOService, didChangeState state: ServerConnectionState) {
        connectionState = state

        switch state {
        case .connected:
            connectionStartDate = Date()
            startWatchdog()
        case .disconnected:
            stopWatchdog()
        case .error:
            // If auth failed, clear token so next attempt uses password
            try? KeychainService.deleteToken(for: server.id)
            stopWatchdog()
        default:
            break
        }
    }

    func socketServiceTokenAuthFailed(_ service: SocketIOService) {
        // Stale JWT token — clear it and reconnect with password
        try? KeychainService.deleteToken(for: server.id)
        service.disconnect()
        socketService = nil

        guard (try? KeychainService.getPassword(for: server.id)) ?? nil != nil else {
            connectionState = .error("Token expired and no password available")
            return
        }

        // Token deleted above, so startConnection() will fall through to password auth
        startConnection()
    }

    func socketService(_ service: SocketIOService, didReceiveMonitorList newMonitors: [Int: Monitor]) {
        lastDataReceivedDate = Date()
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
        lastDataReceivedDate = Date()
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

    // MARK: - Connection Watchdog

    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(ServerConnectionViewModel.watchdogCheckInterval))
                guard !Task.isCancelled else { break }
                self?.checkConnectionHealth()
            }
        }
    }

    private func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    private func checkConnectionHealth() {
        guard connectionState.isConnected else { return }

        let now = Date()
        let timeout = Self.staleConnectionTimeout

        let isStale: Bool
        if let lastData = lastDataReceivedDate {
            isStale = now.timeIntervalSince(lastData) > timeout
        } else if let connectedSince = connectionStartDate {
            isStale = now.timeIntervalSince(connectedSince) > timeout
        } else {
            isStale = false
        }

        if isStale {
            reconnectStale()
        }
    }

    private func reconnectStale() {
        stopWatchdog()
        lastDataReceivedDate = nil
        connectionStartDate = nil

        socketService?.disconnect()
        socketService = nil

        startConnection()
    }
}
