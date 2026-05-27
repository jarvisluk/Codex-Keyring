import SwiftUI
import CodexKeyringUI

@main
struct CodexKeyringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AccountStore
    @StateObject private var settingsPresentation: SettingsPresentationStore

    init() {
        let store = AccountStoreFactory.makeStore()
        let settingsPresentation = SettingsPresentationStore()
        _store = StateObject(wrappedValue: store)
        _settingsPresentation = StateObject(wrappedValue: settingsPresentation)
        MainWindowController.shared.configure(
            store: store,
            settingsPresentation: settingsPresentation
        )
    }

    var body: some Scene {
        Window("Codex Keyring", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(settingsPresentation)
                .frame(minWidth: 920, minHeight: 600)
        }
        .defaultSize(width: 1040, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    presentSettings()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(after: .appInfo) {
                Button("Refresh Accounts") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.isRefreshInProgress || settingsPresentation.isPresented)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(settingsPresentation)
        } label: {
            Image(systemName: store.activeAccount == nil ? "person.crop.circle.badge.questionmark" : "person.crop.circle.badge.checkmark")
        }
        .menuBarExtraStyle(.menu)
    }

    @MainActor
    private func presentSettings() {
        MainWindowController.shared.show()
        settingsPresentation.present()
    }
}
