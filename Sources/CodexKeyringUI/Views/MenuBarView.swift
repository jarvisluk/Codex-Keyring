import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        VStack {
            if let active = store.activeAccount {
                Label(active.displayName, systemImage: "checkmark.circle.fill")
                Text(active.displayEmail)
                    .foregroundStyle(.secondary)
            } else {
                Label("No active saved account", systemImage: "person.crop.circle.badge.questionmark")
            }

            Divider()

            Button("Open Manager") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Add Current Login") {
                store.addCurrentAccount(alias: nil)
            }

            Button("Refresh") {
                store.refresh()
            }

            if !store.accounts.isEmpty {
                Divider()
                ForEach(store.accounts) { account in
                    Button(menuTitle(for: account)) {
                        store.switchTo(account, restartCodexApp: store.settings.restartCodexAppAfterSwitch)
                    }
                    .disabled(store.activeAccount?.id == account.id)
                }
            }

            Divider()

            Toggle("Restart Codex App on Switch", isOn: Binding(
                get: { store.settings.restartCodexAppAfterSwitch },
                set: { store.settings.restartCodexAppAfterSwitch = $0 }
            ))

            SettingsLink {
                Text("Settings")
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }

    private func menuTitle(for account: CodexAccount) -> String {
        let title = account.alias.isEmpty ? account.displayEmail : account.alias
        return title.count > 30 ? String(title.prefix(27)) + "..." : title
    }
}
