import SwiftUI
import CodexKeyringDomain

extension ContentView {
    var selectedAccountID: Binding<UUID?> {
        Binding {
            guard let selectedAccountIDString else { return store.activeAccount?.id }
            return UUID(uuidString: selectedAccountIDString)
        } set: { value in
            selectedAccountIDString = value?.uuidString
        }
    }

    var selectedAccount: CodexAccount? {
        if let id = selectedAccountID.wrappedValue,
           let account = store.accounts.first(where: { $0.id == id }) {
            return account
        }
        return store.activeAccount ?? store.accounts.first
    }

    var accountIDs: [UUID] {
        store.accounts.map(\.id)
    }

    func reconcileSelection() {
        let currentID = selectedAccountID.wrappedValue
        if let currentID,
           store.accounts.contains(where: { $0.id == currentID }) {
            return
        }
        selectedAccountID.wrappedValue = store.activeAccount?.id ?? store.accounts.first?.id
    }
}
