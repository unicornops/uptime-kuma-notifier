import SwiftUI

struct SettingsView: View {
    let serverManager: ServerManager
    @State private var selectedServerID: UUID?
    @State private var showingAddSheet = false

    var body: some View {
        HSplitView {
            serverListSidebar
            detailPane
        }
        .frame(width: 650, height: 420)
        .sheet(isPresented: $showingAddSheet) {
            ServerFormView(serverManager: serverManager, existingServer: nil) {
                showingAddSheet = false
            }
        }
    }

    @ViewBuilder
    private var serverListSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedServerID) {
                ForEach(serverManager.servers) { server in
                    HStack {
                        if let connection = serverManager.connections[server.id] {
                            Circle()
                                .fill(connection.connectionState.isConnected ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                        Text(server.name)
                    }
                    .tag(server.id)
                }
            }

            Divider()

            HStack {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Button(action: removeSelected) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)
                .disabled(selectedServerID == nil)

                Spacer()
            }
            .padding(8)
        }
        .frame(minWidth: 180, maxWidth: 220)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedServerID, let server = serverManager.servers.first(where: { $0.id == id }) {
            ServerFormView(serverManager: serverManager, existingServer: server) {
                // No dismiss action for inline editing
            }
        } else {
            VStack {
                Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundStyle(.quaternary)
                Text("Select a server or add a new one")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func removeSelected() {
        guard let id = selectedServerID else { return }
        serverManager.removeServer(id: id)
        selectedServerID = serverManager.servers.first?.id
    }
}
