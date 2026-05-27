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
        .background {
            TitlebarActionAccessory {
                TitlebarActionBar(
                    isLoginInProgress: store.isLoginInProgress,
                    isRefreshInProgress: store.isRefreshInProgress,
                    login: { store.loginNewCodexAccount() },
                    importAuth: importAuthFile,
                    refresh: { store.refresh() }
                )
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

private struct TitlebarActionBar: View {
    var isLoginInProgress: Bool
    var isRefreshInProgress: Bool
    var login: () -> Void
    var importAuth: () -> Void
    var refresh: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: login) {
                TitlebarActionLabel("Add Login", systemImage: isLoginInProgress ? "hourglass" : "plus.circle")
            }
            .disabled(isLoginInProgress)
            .help("Open Codex login and save the new account without switching the current auth.")

            Button(action: importAuth) {
                TitlebarActionLabel("Import", systemImage: "square.and.arrow.down")
            }
            .help("Import Codex auth.json")

            Button(action: refresh) {
                TitlebarActionLabel("Refresh", systemImage: "arrow.clockwise", isLoading: isRefreshInProgress)
            }
            .disabled(isRefreshInProgress)
            .help("Refresh accounts")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct TitlebarActionLabel: View {
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
        .labelStyle(.iconOnly)
        .font(.system(size: 19, weight: .medium))
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
    }
}

private struct TitlebarActionAccessory<Content: View>: NSViewRepresentable {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window, content: content)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private var accessory: NSTitlebarAccessoryViewController?
        private var hostingController: NSHostingController<Content>?
        private weak var attachedWindow: NSWindow?

        @MainActor
        func attach(to window: NSWindow?, content: Content) {
            guard let window else { return }

            if attachedWindow !== window {
                detach()

                let hostingController = NSHostingController(rootView: content)
                hostingController.view.frame = NSRect(x: 0, y: 0, width: 150, height: 44)

                let accessory = NSTitlebarAccessoryViewController()
                accessory.layoutAttribute = .right
                accessory.view = hostingController.view

                window.addTitlebarAccessoryViewController(accessory)

                self.accessory = accessory
                self.hostingController = hostingController
                attachedWindow = window
            } else {
                hostingController?.rootView = content
            }
        }

        @MainActor
        func detach() {
            if let accessory,
               let window = attachedWindow,
               let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            accessory = nil
            hostingController = nil
            attachedWindow = nil
        }
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
