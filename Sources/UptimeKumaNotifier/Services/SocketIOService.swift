import Foundation
import SocketIO

@MainActor
protocol SocketIOServiceDelegate: AnyObject {
    func socketService(_ service: SocketIOService, didChangeState state: ServerConnectionState)
    func socketService(_ service: SocketIOService, didReceiveMonitorList monitors: [Int: Monitor])
    func socketService(_ service: SocketIOService, didReceiveHeartbeat heartbeat: Heartbeat)
    func socketServiceTokenAuthFailed(_ service: SocketIOService)
}

final class SocketIOService: @unchecked Sendable {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private let serverConfig: Server
    private weak var delegate: (any SocketIOServiceDelegate)?
    private var storedPassword: String?
    private var tokenAuthTimer: DispatchWorkItem?
    private var tokenAuthSucceeded = false

    init(server: Server, delegate: any SocketIOServiceDelegate) {
        self.serverConfig = server
        self.delegate = delegate
    }

    /// Normalizes a URL by removing standard ports (443 for HTTPS, 80 for HTTP)
    /// to avoid origin mismatch issues with WebSocket connections
    private func normalizedWebSocketURL(from urlString: String) -> URL? {
        guard var urlComponents = URLComponents(string: urlString) else {
            return nil
        }

        // Remove standard ports to avoid origin mismatch
        if let port = urlComponents.port {
            if (urlComponents.scheme == "https" && port == 443) ||
               (urlComponents.scheme == "http" && port == 80) {
                urlComponents.port = nil
            }
        }

        return urlComponents.url
    }

    func connect(password: String) {
        guard let url = normalizedWebSocketURL(from: serverConfig.url) else {
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

        setupEventHandlers(socket: socket, password: password, token: nil, initialTwoFactorToken: nil)

        notifyDelegate(state: .connecting)
        socket.connect()
    }

    func connectWithToken(_ token: String, password: String) {
        guard let url = normalizedWebSocketURL(from: serverConfig.url) else {
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

        setupEventHandlers(socket: socket, password: password, token: token, initialTwoFactorToken: nil)

        notifyDelegate(state: .connecting)
        socket.connect()
    }

    func connectWithTwoFactor(password: String, twoFactorToken: String) {
        guard let url = normalizedWebSocketURL(from: serverConfig.url) else {
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

        // Store the 2FA token for later use if needed
        setupEventHandlers(socket: socket, password: password, initialTwoFactorToken: twoFactorToken)

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
            self?.handleLoginResponse(data, serverID: serverID, availableTwoFactorToken: nil)
        }
    }

    func disconnect() {
        tokenAuthTimer?.cancel()
        tokenAuthTimer = nil
        socket?.disconnect()
        socket?.removeAllHandlers()
        manager?.disconnect()
        socket = nil
        manager = nil
    }

    // MARK: - Private

    private func setupEventHandlers(socket: SocketIOClient, password: String, token: String? = nil, initialTwoFactorToken: String? = nil) {
        let serverID = serverConfig.id
        let username = serverConfig.username

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self else { return }
            self.notifyDelegate(state: .authenticating)

            if let token {
                self.tokenAuthSucceeded = false
                socket.emit("loginByToken", token)

                // loginByToken has no ack — if the token is stale the server
                // silently ignores it. Set a timeout so we can fall back to
                // password-based auth.
                let timeout = DispatchWorkItem { [weak self] in
                    guard let self, !self.tokenAuthSucceeded else { return }
                    Task { @MainActor [weak self] in
                        guard let self, let delegate = self.delegate else { return }
                        delegate.socketServiceTokenAuthFailed(self)
                    }
                }
                self.tokenAuthTimer = timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
            } else {
                // Always start with username/password login (no token initially)
                // If 2FA is required, the server will respond with tokenRequired: true
                let loginData: [String: Any] = [
                    "username": username,
                    "password": password,
                    "token": "",
                ]
                socket.emitWithAck("login", loginData).timingOut(after: 30) { [weak self] data in
                    self?.handleLoginResponse(data, serverID: serverID, availableTwoFactorToken: initialTwoFactorToken)
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

    private func handleLoginResponse(_ data: [Any], serverID: UUID, availableTwoFactorToken: String? = nil) {
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
            // If we have a 2FA token available, submit it automatically
            if let twoFactorToken = availableTwoFactorToken, !twoFactorToken.isEmpty {
                let loginData: [String: Any] = [
                    "username": serverConfig.username,
                    "password": storedPassword ?? "",
                    "token": twoFactorToken,
                ]
                socket?.emitWithAck("login", loginData).timingOut(after: 30) { [weak self] data in
                    self?.handleLoginResponse(data, serverID: serverID)
                }
            } else {
                notifyDelegate(state: .twoFactorRequired)
            }
        } else {
            let msg = response["msg"] as? String ?? "Authentication failed"
            notifyDelegate(state: .error(msg))
            // Clear any stale token
            try? KeychainService.deleteToken(for: serverID)
        }
    }

    private func handleMonitorList(_ data: [Any]) {
        guard let dict = data.first as? [String: Any] else { return }

        // Token auth succeeded — cancel the fallback timer
        tokenAuthSucceeded = true
        tokenAuthTimer?.cancel()
        tokenAuthTimer = nil

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
