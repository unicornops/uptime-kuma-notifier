import SwiftUI

struct MonitorListView: View {
    let server: Server
    let connection: ServerConnectionViewModel
    let serverManager: ServerManager
    let onReconnect: () -> Void
    let onSubmitTwoFactor: (String) -> Void

    @State private var isExpanded = true
    @State private var twoFactorCode = ""

    private var monitorsToDisplay: [Int: Monitor] {
        if serverManager.isRefreshing, let lastKnown = serverManager.lastKnownMonitors[server.id] {
            return lastKnown
        }
        return connection.monitors
    }

    private var sortedMonitorsToDisplay: [Monitor] {
        monitorsToDisplay.values
            .filter { $0.active }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status.rawValue < rhs.status.rawValue
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if connection.connectionState.isConnected {
                if sortedMonitorsToDisplay.isEmpty {
                    Text("No monitors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                } else {
                    ForEach(sortedMonitorsToDisplay) { monitor in
                        MonitorRowView(monitor: monitor)
                    }
                }
            } else if case .twoFactorRequired = connection.connectionState {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enter 2FA code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("000000", text: $twoFactorCode)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .frame(maxWidth: 80)
                            .onSubmit {
                                submitTwoFactor()
                            }
                        Button("Submit") {
                            submitTwoFactor()
                        }
                        .font(.caption)
                        .disabled(twoFactorCode.count < 6)
                    }
                }
                .padding(.leading, 8)
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
        if connection.connectionState == .connecting || connection.connectionState == .authenticating {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
        } else {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
        }
    }

    private var downCountToDisplay: Int {
        monitorsToDisplay.values.filter { $0.active && $0.status == .down }.count
    }

    private var indicatorColor: Color {
        switch connection.connectionState {
        case .connected:
            return downCountToDisplay > 0 ? .red : .green
        case .connecting, .authenticating:
            return .yellow
        case .disconnected:
            return .gray
        case .twoFactorRequired:
            return .yellow
        case .error:
            return .red
        }
    }

    private func submitTwoFactor() {
        let code = twoFactorCode.trimmingCharacters(in: .whitespaces)
        guard code.count >= 6 else { return }
        onSubmitTwoFactor(code)
        twoFactorCode = ""
    }
}
