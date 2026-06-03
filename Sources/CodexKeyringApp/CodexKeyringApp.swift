import SwiftUI
import CodexKeyringUI

@main
struct CodexKeyringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openSettings) private var openSettings
    @StateObject private var store: AccountStore

    init() {
        let store = AccountStoreFactory.makeStore()
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        Window(MainWindowPresenter.windowTitle, id: MainWindowPresenter.windowID) {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 500)
        }
        .defaultSize(width: 1040, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(after: .appInfo) {
                Button("Refresh Accounts") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.isRefreshInProgress)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            let presentation = AppMenuBarPresentation(activeAccount: store.activeAccount)
            AppMenuBarIconView(isActive: presentation.isActive)
                .accessibilityLabel(presentation.statusLabel)
                .help(presentation.statusLabel)
        }
        .menuBarExtraStyle(.menu)
    }
}
