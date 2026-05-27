import SwiftUI
import CodexKeyringDomain

public struct ContentView: View {
    public init() {}
    @EnvironmentObject private var store: AccountStore
    @EnvironmentObject private var settingsPresentation: SettingsPresentationStore
    @SceneStorage("selectedAccountID") private var selectedAccountIDString: String?
    @State private var showingAddCurrentSheet = false

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

    private var accountIDs: [UUID] {
        store.accounts.map(\.id)
    }

    public var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(
                    selection: selectedAccountID,
                    onAddCurrentLogin: showAddCurrentLoginSheet
                )
            } detail: {
                detailContent
            }
                .disabled(settingsPresentation.isPresented)

            if settingsPresentation.isPresented {
                SettingsModalOverlay {
                    settingsPresentation.dismiss()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(1)
            }
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
                .disabled(!store.canLoginNewAccount || settingsPresentation.isPresented)
                .help("Open Codex login and save the new account without switching the current auth.")

                Button {
                    importAuthFile()
                } label: {
                    ToolbarActionLabel("Import", systemImage: "square.and.arrow.down")
                }
                .disabled(!store.canImportAccount || settingsPresentation.isPresented)
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
                .disabled(!store.canRefreshAccounts || settingsPresentation.isPresented)
                .help("Refresh accounts")
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
        .animation(.easeInOut(duration: 0.16), value: settingsPresentation.isPresented)
    }

    @ViewBuilder
    private var detailContent: some View {
        if let selectedAccount {
            AccountDetailView(account: selectedAccount)
        } else {
            EmptyAccountsView(
                onAddCurrentLogin: showAddCurrentLoginSheet,
                onImport: importAuthFile
            )
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

    private func showAddCurrentLoginSheet() {
        guard store.canAddCurrentLogin else { return }
        showingAddCurrentSheet = true
    }
}

private struct SettingsModalOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            SettingsView(onDismiss: onDismiss)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(
                        cornerRadius: KeyringStyle.Radius.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: KeyringStyle.Radius.card,
                        style: .continuous
                    )
                    .stroke(.quaternary, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand(perform: onDismiss)
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
    @EnvironmentObject private var store: AccountStore
    let onAddCurrentLogin: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: KeyringStyle.Spacing.cardPadding) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: KeyringStyle.Icon.emptyStateSize))
                .foregroundStyle(.secondary)

            Text("No saved accounts")
                .font(.title2.weight(.semibold))

            Text("Add a Codex login or import an auth.json snapshot to begin.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: KeyringStyle.Spacing.compact) {
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
                    onImport()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(!store.canImportAccount)
            }
            .padding(.top, KeyringStyle.Spacing.micro)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(KeyringStyle.Spacing.detailPagePadding)
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
