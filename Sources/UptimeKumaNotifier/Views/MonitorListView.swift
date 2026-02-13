import SwiftUI

struct MonitorListView: View {
    let server: Server
    let connection: ServerConnectionViewModel
    let onReconnect: () -> Void
    let onSubmitTwoFactor: (String) -> Void

    @State private var isExpanded = true
    @State private var twoFactorCode = ""

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if connection.connectionState.isConnected {
                if connection.sortedMonitors.isEmpty {
                    if connection.connectionState == .connecting || connection.connectionState == .authenticating {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading monitors...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    } else {
                        Text("No monitors")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                } else {
                    ForEach(connection.sortedMonitors) { monitor in
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

    private var indicatorColor: Color {
        switch connection.connectionState {
        case .connected:
            return connection.downCount > 0 ? .red : .green
        case .connecting, .authenticating:
            // If we have monitor data during reconnection, show the appropriate color
            if !connection.sortedMonitors.isEmpty {
                return connection.downCount > 0 ? .red : .green
            } else {
                return .yellow
            }
        case .disconnected:
            // If we have monitor data but are disconnected, show the last known status
            if !connection.sortedMonitors.isEmpty {
                return connection.downCount > 0 ? .red : .green
            } else {
                return .gray
            }
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
