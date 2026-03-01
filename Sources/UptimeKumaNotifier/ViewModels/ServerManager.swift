import Foundation
import SwiftUI
import AppKit

@Observable
@MainActor
final class ServerManager {
    var servers: [Server] = []
    var connections: [UUID: ServerConnectionViewModel] = [:]
    var isRefreshing = false

    private static let serversKey = "savedServers"
    private nonisolated(unsafe) var sleepWakeObserver: NSObjectProtocol?

    init() {
        loadServers()
        setupSleepWakeObserver()
    }

    deinit {
        if let observer = sleepWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Computed Properties

    var totalDownCount: Int {
        connections.values.reduce(0) { $0 + $1.downCount }
    }

    var totalUpCount: Int {
        connections.values.reduce(0) { $0 + $1.upCount }
    }

    var allOperational: Bool {
        !servers.isEmpty && totalDownCount == 0 && connections.values.contains(where: { $0.connectionState.isConnected })
    }

    var hasAnyConnection: Bool {
        connections.values.contains { $0.connectionState.isConnected }
    }

    var menuBarSystemImage: String {
        if servers.isEmpty { return "questionmark.circle" }
        if !hasAnyConnection { return "network.slash" }
        if allOperational { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    var menuBarLabel: String? {
        let down = totalDownCount
        if down > 0 { return "\(down)" }
        return nil
    }

    // MARK: - Server Management

    func addServer(_ server: Server, password: String) {
        servers.append(server)
        try? KeychainService.savePassword(password, for: server.id)
        if let twoFactorToken = server.twoFactorToken {
            try? KeychainService.saveTwoFactorToken(twoFactorToken, for: server.id)
        }
        saveServers()

        let vm = ServerConnectionViewModel(server: server)
        connections[server.id] = vm
        vm.connect()
    }

    func updateServer(_ server: Server, password: String?) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server

            if let password {
                try? KeychainService.savePassword(password, for: server.id)
                try? KeychainService.deleteToken(for: server.id)
            }

            // Handle 2FA token updates
            if let twoFactorToken = server.twoFactorToken, !twoFactorToken.isEmpty {
                try? KeychainService.saveTwoFactorToken(twoFactorToken, for: server.id)
            } else {
                try? KeychainService.deleteTwoFactorToken(for: server.id)
            }

            saveServers()

            // Reconnect with updated config
            connections[server.id]?.disconnect()
            let vm = ServerConnectionViewModel(server: server)
            connections[server.id] = vm
            vm.connect()
        }
    }

    func removeServer(id: UUID) {
        connections[id]?.disconnect()
        connections.removeValue(forKey: id)
        servers.removeAll { $0.id == id }
        try? KeychainService.deleteAll(for: id)
        saveServers()
    }

    func connectAll() {
        for server in servers {
            if connections[server.id] == nil {
                // No existing connection, create a new one
                let vm = ServerConnectionViewModel(server: server)
                connections[server.id] = vm
            }
            // Only connect if not already connected
            if !connections[server.id]!.connectionState.isConnected {
                connections[server.id]?.connect()
            }
        }
    }

    func disconnectAll() {
        for connection in connections.values {
            connection.disconnect()
        }
    }

    func reconnectServer(id: UUID) {
        guard let server = servers.first(where: { $0.id == id }) else { return }
        // Preserve existing monitor data during reconnect
        let existingMonitors = connections[id]?.monitors ?? [:]
        connections[id]?.disconnect()
        let vm = ServerConnectionViewModel(server: server, existingMonitors: existingMonitors)
        connections[id] = vm
        vm.connect()
    }

    func refreshAllServers() {
        isRefreshing = true
        for server in servers {
            // Preserve existing monitor data during refresh
            let existingMonitors = connections[server.id]?.monitors ?? [:]
            connections[server.id]?.disconnect()
            // Use convenience initializer to preserve monitor data and set proper connection state
            let vm = ServerConnectionViewModel(server: server, existingMonitors: existingMonitors)
            connections[server.id] = vm
            vm.connect()
        }
        // Reset refreshing state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isRefreshing = false
        }
    }

    // MARK: - Sleep/Wake

    private func setupSleepWakeObserver() {
        sleepWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Brief delay to allow the network to re-establish after wake
                try? await Task.sleep(for: .seconds(3))
                self?.refreshAllServers()
            }
        }
    }

    // MARK: - Persistence

    private func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: Self.serversKey) else { return }
        do {
            servers = try JSONDecoder().decode([Server].self, from: data)
        } catch {
            print("Failed to load servers: \(error.localizedDescription)")
        }
    }

    private func saveServers() {
        do {
            let data = try JSONEncoder().encode(servers)
            UserDefaults.standard.set(data, forKey: Self.serversKey)
        } catch {
            print("Failed to save servers: \(error.localizedDescription)")
        }
    }
}
