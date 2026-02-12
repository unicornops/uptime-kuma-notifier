import Foundation

enum MonitorStatus: Int, Codable, Sendable {
    case down = 0
    case up = 1
    case pending = 2
    case maintenance = 3

    var label: String {
        switch self {
        case .down: "Down"
        case .up: "Up"
        case .pending: "Pending"
        case .maintenance: "Maintenance"
        }
    }

    var isOperational: Bool {
        self == .up || self == .maintenance
    }

    var sfSymbol: String {
        switch self {
        case .down: "xmark.circle.fill"
        case .up: "checkmark.circle.fill"
        case .pending: "questionmark.circle.fill"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }
}
