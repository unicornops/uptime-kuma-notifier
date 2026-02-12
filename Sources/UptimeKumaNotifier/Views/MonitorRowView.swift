import SwiftUI

struct MonitorRowView: View {
    let monitor: Monitor

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: monitor.status.sfSymbol)
                .foregroundStyle(statusColor)
                .font(.body)

            VStack(alignment: .leading, spacing: 1) {
                Text(monitor.name)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)

                if let heartbeat = monitor.latestHeartbeat, !heartbeat.message.isEmpty {
                    Text(heartbeat.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let ping = monitor.latestHeartbeat?.ping {
                Text("\(ping)ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
    }

    private var statusColor: Color {
        switch monitor.status {
        case .up: .green
        case .down: .red
        case .pending: .yellow
        case .maintenance: .blue
        }
    }
}
