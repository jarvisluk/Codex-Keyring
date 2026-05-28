import SwiftUI
import CodexKeyringDomain

struct SidebarView: View {
    @EnvironmentObject private var store: AccountStore
    @Binding var selection: UUID?
    let onAddCurrentLogin: () -> Void
    private let minimumColumnWidth: CGFloat = 220
    private let defaultColumnWidth: CGFloat = 288
    private let maximumColumnWidth: CGFloat = 520

    var body: some View {
        List(selection: $selection) {
            Section("Accounts") {
                ForEach(store.accounts) { account in
                    SidebarAccountRow(
                        account: account,
                        isActive: store.activeAccount?.id == account.id,
                        isSelected: selection == account.id,
                        quotaState: store.quotaStates[account.id]
                    )
                    .tag(account.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: minimumColumnWidth,
            ideal: defaultColumnWidth,
            max: maximumColumnWidth
        )
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.small) {
                CurrentAuthFooter(onAddCurrentLogin: onAddCurrentLogin)
                SidebarStatusFooter()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(KeyringStyle.Spacing.sidebarFooterPadding)
        }
    }
}
