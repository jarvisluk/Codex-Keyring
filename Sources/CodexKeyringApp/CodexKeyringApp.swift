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
    }

    var body: some Scene {
        Window(MainWindowPresenter.windowTitle, id: MainWindowPresenter.windowID) {
            ContentView()
                .environmentObject(store)
                .environmentObject(settingsPresentation)
                .frame(minWidth: 760, minHeight: 500)
        }
        .defaultSize(width: 1040, height: 680)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(settingsPresentation)
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
