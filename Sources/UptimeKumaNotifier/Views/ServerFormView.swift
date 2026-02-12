import SwiftUI

struct ServerFormView: View {
    let serverManager: ServerManager
    let existingServer: Server?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showingDeleteConfirmation = false

    private var isNew: Bool { existingServer == nil }

    var body: some View {
        Form {
            Section {
                TextField("Display Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Server URL", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            } header: {
                Text(isNew ? "Add Server" : "Edit Server")
                    .font(.headline)
            }

            if !isNew {
                if let connection = serverManager.connections[existingServer!.id] {
                    Section {
                        LabeledContent("Status") {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(connection.connectionState.isConnected ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(connection.connectionState.label)
                                    .font(.caption)
                            }
                        }

                        LabeledContent("Monitors") {
                            Text("\(connection.monitors.count)")
                                .font(.caption)
                        }
                    } header: {
                        Text("Connection")
                    }
                }
            }

            Section {
                HStack {
                    if isNew {
                        Button("Cancel") {
                            onDismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                    } else {
                        Button("Delete Server", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }

                    Spacer()

                    Button(isNew ? "Add Server" : "Save") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 380)
        .onAppear {
            loadExisting()
        }
        .confirmationDialog(
            "Delete \(existingServer?.name ?? "server")?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = existingServer?.id {
                    serverManager.removeServer(id: id)
                }
            }
        } message: {
            Text("This will remove the server and all its credentials. This action cannot be undone.")
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !url.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && (isNew ? !password.isEmpty : true)
    }

    private func loadExisting() {
        guard let server = existingServer else { return }
        name = server.name
        url = server.url
        username = server.username
        password = ""
    }

    private func save() {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if let existing = existingServer {
            let updated = Server(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                url: trimmedURL,
                username: username.trimmingCharacters(in: .whitespaces)
            )
            serverManager.updateServer(updated, password: password.isEmpty ? nil : password)
        } else {
            let server = Server(
                name: name.trimmingCharacters(in: .whitespaces),
                url: trimmedURL,
                username: username.trimmingCharacters(in: .whitespaces)
            )
            serverManager.addServer(server, password: password)
            onDismiss()
        }
    }
}
