import SwiftUI

public struct MenuBarView: View {
    @EnvironmentObject private var store: AccountStore

    public init() {}

    public var body: some View {
        VStack {
            if store.activeAccount == nil {
                Label("No active saved account", systemImage: "person.crop.circle.badge.questionmark")
                Divider()
            }

            MenuBarOpenManagerAction()

            MenuBarAddCurrentLoginAction()

            MenuBarRefreshQuotasAction()

            MenuBarAccountsSection()

            Divider()

            MenuBarAppActionsSection()
        }
    }
}
