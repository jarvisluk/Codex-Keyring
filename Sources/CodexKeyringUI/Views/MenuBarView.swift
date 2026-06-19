import SwiftUI

public struct MenuBarView: View {
    @EnvironmentObject private var store: AccountStore
    @Binding private var showsAccountSensitiveValues: Bool

    public init(showsAccountSensitiveValues: Binding<Bool> = .constant(false)) {
        _showsAccountSensitiveValues = showsAccountSensitiveValues
    }

    public var body: some View {
        VStack {
            if store.activeAccount == nil {
                Label("No active saved account", systemImage: "person.crop.circle.badge.questionmark")
                Divider()
            }

            MenuBarOpenManagerAction()

            Button {
                showsAccountSensitiveValues.toggle()
            } label: {
                Label(
                    showsAccountSensitiveValues ? "Hide Sensitive Info" : "Show Sensitive Info",
                    systemImage: showsAccountSensitiveValues ? "eye.slash" : "eye"
                )
            }

            MenuBarAddCurrentLoginAction()

            MenuBarRefreshQuotasAction()

            MenuBarAccountsSection()

            Divider()

            MenuBarAppActionsSection()
        }
        .environment(\.accountSensitiveValuesVisible, showsAccountSensitiveValues)
    }
}
