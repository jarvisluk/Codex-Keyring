import SwiftUI

extension View {
    func accountStoreFailureAlert(_ store: AccountStore) -> some View {
        modifier(AccountStoreFailureAlert(store: store))
    }
}

private struct AccountStoreFailureAlert: ViewModifier {
    @ObservedObject var store: AccountStore

    func body(content: Content) -> some View {
        content.alert("Action failed", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("OK") {
                store.clearError()
            }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}
