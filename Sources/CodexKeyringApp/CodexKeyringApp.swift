import SwiftUI
import CodexKeyringUI

@main
struct CodexKeyringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AccountStore
    @StateObject private var settingsPresentation: SettingsPresentationStore
    @StateObject private var softwareUpdates: SoftwareUpdateController
    @State private var showsAccountSensitiveValues = false

    init() {
        let store = AccountStoreFactory.makeStore()
        let settingsPresentation = SettingsPresentationStore()
        _store = StateObject(wrappedValue: store)
        _settingsPresentation = StateObject(wrappedValue: settingsPresentation)
        _softwareUpdates = StateObject(wrappedValue: SoftwareUpdateController())
    }

    var body: some Scene {
        Window(MainWindowPresenter.windowTitle, id: MainWindowPresenter.windowID) {
            ContentView(showsAccountSensitiveValues: $showsAccountSensitiveValues)
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
                .environmentObject(softwareUpdates)
        }

        MenuBarExtra {
            MenuBarView(showsAccountSensitiveValues: $showsAccountSensitiveValues)
                .environmentObject(store)
        } label: {
            let presentation = AppMenuBarPresentation(
                activeAccount: store.activeAccount,
                showsSensitiveValues: showsAccountSensitiveValues
            )
            AppMenuBarIconView(isActive: presentation.isActive)
                .accessibilityLabel(presentation.statusLabel)
                .help(presentation.statusLabel)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    softwareUpdates.checkForUpdates()
                }
                .disabled(!softwareUpdates.canCheckForUpdates)
            }
        }
    }
}
