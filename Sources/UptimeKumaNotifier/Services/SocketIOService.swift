import Foundation
import SocketIO

@MainActor
protocol SocketIOServiceDelegate: AnyObject {
    func socketService(_ service: SocketIOService, didChangeState state: ServerConnectionState)
    func socketService(_ service: SocketIOService, didReceiveMonitorList monitors: [Int: Monitor])
    func socketService(_ service: SocketIOService, didReceiveHeartbeat heartbeat: Heartbeat)
}

final class SocketIOService: @unchecked Sendable {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private let serverConfig: Server
    private weak var delegate: (any SocketIOServiceDelegate)?
    private var storedPassword: String?

    init(server: Server, delegate: any SocketIOServiceDelegate) {
        self.serverConfig = server
        self.delegate = delegate
    }

    func connect(password: String) {
        guard let url = URL(string: serverConfig.url) else {
            notifyDelegate(state: .error("Invalid server URL"))
            return
        }

        self.storedPassword = password
        disconnect()

        let manager = SocketManager(
            socketURL: url,
            config: [
                .log(false),
                .compress,
                .forceWebsockets(true),
                .reconnects(true),
                .reconnectWait(5),
                .reconnectAttempts(-1),
                .version(.three),
            ]
        )

        self.manager = manager
        let socket = manager.defaultSocket
        self.socket = socket

        setupEventHandlers(socket: socket, password: password)

        notifyDelegate(state: .connecting)
        socket.connect()
    }

    func connectWithToken(_ token: String, password: String) {
        guard let url = URL(string: serverConfig.url) else {
            notifyDelegate(state: .error("Invalid server URL"))
            return
        }

        self.storedPassword = password
        disconnect()

        let manager = SocketManager(
            socketURL: url,
            config: [
                .log(false),
                .compress,
                .forceWebsockets(true),
                .reconnects(true),
                .reconnectWait(5),
                .reconnectAttempts(-1),
                .version(.three),
            ]
        )

        self.manager = manager
        let socket = manager.defaultSocket
        self.socket = socket

        setupEventHandlers(socket: socket, password: password, token: token)

        notifyDelegate(state: .connecting)
        socket.connect()
    }

    func submitTwoFactorCode(_ code: String) {
        guard let socket else { return }
        let serverID = serverConfig.id
        let loginData: [String: Any] = [
            "username": serverConfig.username,
            "password": storedPassword ?? "",
            "token": code,
        ]
        notifyDelegate(state: .authenticating)
        socket.emitWithAck("login", loginData).timingOut(after: 30) { [weak self] data in
            self?.handleLoginResponse(data, serverID: serverID)
        }
    }

    func disconnect() {
        socket?.disconnect()
        socket?.removeAllHandlers()
        manager?.disconnect()
        socket = nil
        manager = nil
    }

    // MARK: - Private

    private func setupEventHandlers(socket: SocketIOClient, password: String, token: String? = nil) {
        let serverID = serverConfig.id
        let username = serverConfig.username

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self else { return }
            self.notifyDelegate(state: .authenticating)

            if let token {
                socket.emit("loginByToken", token) { [weak self] in
                    // loginByToken doesn't use ack in the same way, we handle via monitorList arrival
                    _ = self  // prevent unused warning
                }
            } else {
                let loginData: [String: Any] = [
                    "username": username,
                    "password": password,
                    "token": "",
                ]
                socket.emitWithAck("login", loginData).timingOut(after: 30) { [weak self] data in
                    self?.handleLoginResponse(data, serverID: serverID)
                }
            }
        }

        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.notifyDelegate(state: .disconnected)
        }

        socket.on(clientEvent: .error) { [weak self] data, _ in
            let message = (data.first as? String) ?? "Connection error"
            self?.notifyDelegate(state: .error(message))
        }

        socket.on(clientEvent: .reconnect) { [weak self] _, _ in
            self?.notifyDelegate(state: .connecting)
        }

        socket.on("monitorList") { [weak self] data, _ in
            self?.handleMonitorList(data)
        }

        socket.on("heartbeat") { [weak self] data, _ in
            self?.handleHeartbeat(data)
        }
    }

    private func handleLoginResponse(_ data: [Any], serverID: UUID) {
        guard let response = data.first as? [String: Any] else {
            notifyDelegate(state: .error("Invalid login response"))
            return
        }

        let ok = response["ok"] as? Bool ?? false

        if ok {
            if let token = response["token"] as? String {
                try? KeychainService.saveToken(token, for: serverID)
            }
            notifyDelegate(state: .connected)
        } else if response["tokenRequired"] as? Bool == true {
            notifyDelegate(state: .twoFactorRequired)
        } else {
            let msg = response["msg"] as? String ?? "Authentication failed"
            notifyDelegate(state: .error(msg))
            // Clear any stale token
            try? KeychainService.deleteToken(for: serverID)
        }
    }

    private func handleMonitorList(_ data: [Any]) {
        guard let dict = data.first as? [String: Any] else { return }

        var monitors: [Int: Monitor] = [:]
        for (_, value) in dict {
            guard let monitorDict = value as? [String: Any],
                  let monitor = Monitor.from(dictionary: monitorDict) else {
                continue
            }
            monitors[monitor.id] = monitor
        }

        notifyDelegate(state: .connected)

        Task { @MainActor [weak self] in
            guard let self, let delegate = self.delegate else { return }
            delegate.socketService(self, didReceiveMonitorList: monitors)
        }
    }

    private func handleHeartbeat(_ data: [Any]) {
        guard let dict = data.first as? [String: Any],
              let heartbeat = Heartbeat.from(dictionary: dict) else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self, let delegate = self.delegate else { return }
            delegate.socketService(self, didReceiveHeartbeat: heartbeat)
        }
    }

    private func notifyDelegate(state: ServerConnectionState) {
        Task { @MainActor [weak self] in
            guard let self, let delegate = self.delegate else { return }
            delegate.socketService(self, didChangeState: state)
        }
    }
}
