import SwiftUI
import CodexKeyringUI

@main
struct CodexKeyringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var store: AccountStore
    @StateObject private var settingsPresentation: SettingsPresentationStore

    init() {
        let store = AccountStoreFactory.makeStore()
        let settingsPresentation = SettingsPresentationStore()
        _store = StateObject(wrappedValue: store)
        _settingsPresentation = StateObject(wrappedValue: settingsPresentation)
    }

    var body: some Scene {
        Window(MainWindowPresenter.windowTitle, id: MainWindowPresenter.windowID) {
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
            let presentation = AppMenuBarPresentation(activeAccount: store.activeAccount)
            AppMenuBarIconView(isActive: presentation.isActive)
                .accessibilityLabel(presentation.statusLabel)
                .help(presentation.statusLabel)
        }
        .menuBarExtraStyle(.menu)
    }

    @MainActor
    private func presentSettings() {
        MainWindowPresenter.open(using: openWindow)
        settingsPresentation.present()
    }
}
