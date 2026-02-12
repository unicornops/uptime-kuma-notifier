import SwiftUI

struct MonitorListView: View {
    let server: Server
    let connection: ServerConnectionViewModel
    let onReconnect: () -> Void

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if connection.connectionState.isConnected {
                if connection.sortedMonitors.isEmpty {
                    Text("No monitors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                } else {
                    ForEach(connection.sortedMonitors) { monitor in
                        MonitorRowView(monitor: monitor)
                    }
                }
            } else {
                HStack {
                    Text(connection.connectionState.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if case .error = connection.connectionState {
                        Button("Retry") {
                            onReconnect()
                        }
                        .font(.caption)
                    }
                }
                .padding(.leading, 8)
            }
        } label: {
            HStack(spacing: 6) {
                connectionIndicator
                Text(server.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if connection.connectionState.isConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text("\(connection.upCount)")
                            .font(.caption)
                        if connection.downCount > 0 {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption2)
                            Text("\(connection.downCount)")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var connectionIndicator: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 8, height: 8)
    }

    private var indicatorColor: Color {
        switch connection.connectionState {
        case .connected:
            connection.downCount > 0 ? .red : .green
        case .connecting, .authenticating:
            .yellow
        case .disconnected:
            .gray
        case .error:
            .red
        }
    }
}
