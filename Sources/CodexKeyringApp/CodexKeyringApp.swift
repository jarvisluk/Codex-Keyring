import AppKit
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
            Image(systemName: menuBarSystemImage)
                .accessibilityLabel(menuBarStatusLabel)
                .help(menuBarStatusLabel)
        }
        .menuBarExtraStyle(.menu)
    }

    @MainActor
    private func presentSettings() {
        openManagerWindow()
        settingsPresentation.present()
    }

    @MainActor
    private func openManagerWindow() {
        if let existingWindow = existingManagerWindow {
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private var existingManagerWindow: NSWindow? {
        NSApp.windows.first { window in
            window.identifier?.rawValue == "main"
                || window.title == "Codex Keyring"
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
