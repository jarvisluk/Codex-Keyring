import SwiftUI
import CodexKeyringUI

struct AccountCommands: Commands {
    @ObservedObject var store: AccountStore

    var body: some Commands {
        CommandMenu("Accounts") {
            Button("Open Manager") {
                MainWindowController.shared.show()
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()

            Button("Add New Login") {
                MainWindowController.shared.showAddNewLoginFlow()
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(!store.canLoginNewAccount)

            Button("Save Current Login") {
                MainWindowController.shared.showAddCurrentLoginSheet()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!store.canAddCurrentLogin)

            Button("Import Auth Snapshot...") {
                MainWindowController.shared.showImportAuthSnapshotPanel()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(!store.canImportAccount)

            Divider()

            Button("Refresh Accounts") {
                store.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!store.canRefreshAccounts)

            Button("Refresh Quotas") {
                store.refreshQuotasNow()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!store.canRefreshQuotas)
        }
    }
}
