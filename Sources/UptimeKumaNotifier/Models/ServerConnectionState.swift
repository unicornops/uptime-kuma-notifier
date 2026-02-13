import Foundation

enum ServerConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case authenticating
    case connected
    case twoFactorRequired
    case error(String)

    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting..."
        case .authenticating: "Authenticating..."
        case .connected: "Connected"
        case .twoFactorRequired: "2FA Required"
        case .error(let msg): "Error: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
