import SwiftUI
import UniformTypeIdentifiers
import CodexKeyringDomain

public struct ContentView: View {
    public init() {}
    @EnvironmentObject private var store: AccountStore
    @SceneStorage("selectedAccountID") private var selectedAccountIDString: String?

    private var selectedAccountID: Binding<UUID?> {
        Binding {
            guard let selectedAccountIDString else { return store.activeAccount?.id }
            return UUID(uuidString: selectedAccountIDString)
        } set: { value in
            selectedAccountIDString = value?.uuidString
        }
    }

    private var selectedAccount: CodexAccount? {
        if let id = selectedAccountID.wrappedValue,
           let account = store.accounts.first(where: { $0.id == id }) {
            return account
        }
        return store.activeAccount ?? store.accounts.first
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(selection: selectedAccountID)
        } detail: {
            detailContent
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.loginNewCodexAccount()
                } label: {
                    ToolbarActionLabel(
                        "Add Login",
                        systemImage: store.isLoginInProgress ? "hourglass" : "plus.circle"
                    )
                }
                .disabled(store.isLoginInProgress)
                .help("Open Codex login and save the new account without switching the current auth.")

                Button {
                    importAuthFile()
                } label: {
                    ToolbarActionLabel("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import Codex auth.json")

                Button {
                    store.refresh()
                } label: {
                    ToolbarActionLabel(
                        "Refresh",
                        systemImage: "arrow.clockwise",
                        isLoading: store.isRefreshInProgress
                    )
                }
                .disabled(store.isRefreshInProgress)
                .help("Refresh accounts")
            }
        }
        .alert("Action failed", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("OK") {
                store.clearError()
            }
        } message: {
            Text(store.lastError ?? "")
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let selectedAccount {
            AccountDetailView(account: selectedAccount)
        } else {
            EmptyAccountsView()
        }
    }

    private func importAuthFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Codex auth.json"
        panel.message = "Choose a Codex auth JSON file. Token contents stay on this Mac."
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            store.importAccount(from: url)
        }
    }
}

private struct ToolbarActionLabel: View {
    let title: String
    let systemImage: String
    let isLoading: Bool

    init(_ title: String, systemImage: String, isLoading: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            ZStack {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.primary)
                    .opacity(isLoading ? 0 : 1)

                ProgressView()
                    .controlSize(.small)
                    .opacity(isLoading ? 1 : 0)
            }
            .frame(width: 16, height: 16)
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(title)
    }
}

private struct EmptyAccountsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No saved accounts")
                .font(.title2)
            Text("Add a Codex login or import an auth.json snapshot to begin.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
