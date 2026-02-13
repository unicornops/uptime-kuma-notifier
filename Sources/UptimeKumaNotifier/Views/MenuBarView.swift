import SwiftUI

struct MenuBarView: View {
    let serverManager: ServerManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerSection
            Divider()
            contentSection
            Divider()
            footerSection
        }
        .padding(.vertical, 8)
        .frame(width: 340)
        .onAppear {
            serverManager.connectAll()
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Image(systemName: serverManager.menuBarSystemImage)
                .foregroundStyle(serverManager.allOperational ? .green : (serverManager.hasAnyConnection ? .red : .secondary))
            Text("Uptime Kuma")
                .font(.headline)
            Spacer()
            if serverManager.hasAnyConnection {
                Text("\(serverManager.totalUpCount) up")
                    .foregroundStyle(.green)
                    .font(.caption)
                if serverManager.totalDownCount > 0 {
                    Text("\(serverManager.totalDownCount) down")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var contentSection: some View {
        if serverManager.servers.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No servers configured")
                    .foregroundStyle(.secondary)
                Button("Open Settings...") {
                    openSettingsWindow()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(serverManager.servers) { server in
                        if let connection = serverManager.connections[server.id] {
                            MonitorListView(
                                server: server,
                                connection: connection,
                                onReconnect: { serverManager.reconnectServer(id: server.id) },
                                onSubmitTwoFactor: { code in connection.submitTwoFactorCode(code) }
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        HStack {
            Button("Settings...") {
                openSettingsWindow()
            }
            .buttonStyle(.plain)
            Spacer()
            if serverManager.hasAnyConnection {
                Button("Refresh") {
                    serverManager.refreshAllServers()
                }
                .buttonStyle(.plain)
                if serverManager.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private func openSettingsWindow() {
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }
}
