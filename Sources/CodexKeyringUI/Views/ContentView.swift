import SwiftUI
import CodexKeyringDomain

public struct ContentView: View {
    public init() {}
    @EnvironmentObject private var store: AccountStore
    @SceneStorage("CodexKeyring.selectedAccountID") private var selectedAccountIDString = ""
    @State private var showingAddCurrentSheet = false

    private var selectedAccountID: Binding<UUID?> {
        Binding {
            guard !selectedAccountIDString.isEmpty else { return store.activeAccount?.id }
            return UUID(uuidString: selectedAccountIDString)
        } set: { value in
            selectedAccountIDString = value?.uuidString ?? ""
        }
    }

    private var selectedAccount: CodexAccount? {
        if let id = selectedAccountID.wrappedValue,
           let account = store.accounts.first(where: { $0.id == id }) {
            return account
        }
        return store.activeAccount ?? store.accounts.first
    }

    private var accountIDs: [UUID] {
        store.accounts.map(\.id)
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: selectedAccountID,
                onAddCurrentLogin: showAddCurrentLoginSheet
            )
        } detail: {
            if let selectedAccount {
                AccountDetailView(account: selectedAccount)
            } else {
                EmptyAccountsView(onAddCurrentLogin: showAddCurrentLoginSheet)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    startNewLogin()
                } label: {
                    ToolbarButtonLabel(
                        "Add Login",
                        systemImage: store.isLoginInProgress ? "hourglass" : "plus.circle"
                    )
                }
                .disabled(!store.canLoginNewAccount)
                .help("Open Codex login and save the new account without switching the current auth.")

                Button {
                    importAuthFile()
                } label: {
                    ToolbarButtonLabel("Import", systemImage: "square.and.arrow.down")
                }
                .disabled(!store.canImportAccount)

                Button {
                    store.refresh()
                } label: {
                    ToolbarButtonLabel(
                        "Refresh",
                        systemImage: "arrow.clockwise",
                        isLoading: store.isRefreshInProgress
                    )
                }
                .disabled(!store.canRefreshAccounts)
            }
        }
        .accountStoreFailureAlert(store)
        .sheet(isPresented: $showingAddCurrentSheet) {
            AddCurrentAccountSheet()
                .environmentObject(store)
        }
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: accountIDs) {
            reconcileSelection()
        }
        .onChange(of: store.activeAccountID) {
            reconcileSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .codexKeyringStartNewLogin)) { _ in
            startNewLogin()
        }
        .onReceive(NotificationCenter.default.publisher(for: .codexKeyringShowAddCurrentLoginSheet)) { _ in
            showAddCurrentLoginSheet()
        }
    }

    private func reconcileSelection() {
        let currentID = selectedAccountID.wrappedValue
        if let currentID,
           store.accounts.contains(where: { $0.id == currentID }) {
            return
        }
        selectedAccountID.wrappedValue = store.activeAccount?.id ?? store.accounts.first?.id
    }

    private func importAuthFile() {
        AuthImportPanel.chooseAndImport(using: store)
    }

    private func startNewLogin() {
        guard store.canLoginNewAccount else { return }
        store.loginNewCodexAccount()
    }

    private func showAddCurrentLoginSheet() {
        guard store.canAddCurrentLogin else { return }
        showingAddCurrentSheet = true
    }
}

private struct ToolbarButtonLabel: View {
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
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.primary)
            }
        }
    }
}

private struct EmptyAccountsView: View {
    @EnvironmentObject private var store: AccountStore
    let onAddCurrentLogin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("No saved accounts")
                .font(.title2)

            Text("Add a Codex login or import an auth.json snapshot to begin.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                if store.canSaveCurrentAuth {
                    Button {
                        onAddCurrentLogin()
                    } label: {
                        Label("Save Current Login", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canAddCurrentLogin)
                }

                addLoginButton

                Button {
                    AuthImportPanel.chooseAndImport(using: store)
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(!store.canImportAccount)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var addLoginButton: some View {
        let button = Button {
            store.loginNewCodexAccount()
        } label: {
            Label("Add Login", systemImage: store.isLoginInProgress ? "hourglass" : "person.badge.plus")
        }
        .disabled(!store.canLoginNewAccount)

        if store.canSaveCurrentAuth {
            button.buttonStyle(.bordered)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }
}
