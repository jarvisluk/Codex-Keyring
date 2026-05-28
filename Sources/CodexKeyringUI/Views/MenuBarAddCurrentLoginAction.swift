import SwiftUI

struct MenuBarAddCurrentLoginAction: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        Button("Add Current Login") {
            openAddCurrentLoginSheet()
        }
        .disabled(!store.canAddCurrentLogin)
    }

    private func openAddCurrentLoginSheet() {
        guard store.canAddCurrentLogin else { return }
        MenuBarWindowActions.openManagerAndRun(using: openWindow) {
            MainWindowRequest.showAddCurrentLoginSheet()
        }
    }
}
