import SwiftUI
import CodexKeyringUI

@main
struct CodexKeyringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AccountStore

    init() {
        let store = AccountStoreFactory.makeStore()
        _store = StateObject(wrappedValue: store)
        MainWindowController.shared.configure(store: store)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            Image(systemName: menuBarSystemImage)
                .accessibilityLabel(menuBarStatusLabel)
                .help(menuBarStatusLabel)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            AccountCommands(store: store)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }

    private var menuBarSystemImage: String {
        store.activeAccount == nil
            ? "person.crop.circle.badge.questionmark"
            : "person.crop.circle.badge.checkmark"
    }

    private var menuBarStatusLabel: String {
        guard let activeAccount = store.activeAccount else {
            return "Codex Keyring: no active saved account"
        }
        return "Codex Keyring: \(activeAccount.displayName) active"
    }
}
