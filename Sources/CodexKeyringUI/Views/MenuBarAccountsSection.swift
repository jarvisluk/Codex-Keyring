import SwiftUI
import CodexKeyringDomain

struct MenuBarAccountsSection: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.accountSensitiveValuesVisible) private var showsAccountSensitiveValues

    var body: some View {
        if !store.accounts.isEmpty {
            Divider()
            ForEach(store.accounts) { account in
                accountButton(account)
                quotaLine(for: account)
            }
        }
    }

    private func accountButton(_ account: CodexAccount) -> some View {
        let isActive = store.activeAccount?.id == account.id
        let presentation = MenuBarAccountPresentation(
            account: account,
            isActive: isActive,
            canSwitch: store.canSwitch(to: account),
            showsSensitiveValues: showsAccountSensitiveValues
        )
        return Button {
            guard !isActive else { return }
            store.switchTo(
                account,
                restartCodexApp: store.settings.restartCodexAppAfterSwitch
            )
        } label: {
            Label {
                Text(presentation.title)
            } icon: {
                Image(systemName: presentation.statusSystemImage)
                    .foregroundStyle(presentation.statusIconTint.color)
            }
        }
        .disabled(!presentation.canSwitch)
    }

    @ViewBuilder
    private func quotaLine(for account: CodexAccount) -> some View {
        if let quotaState = store.quotaStates[account.id],
           let presentation = MenuBarQuotaPresentation(state: quotaState) {
            Button {} label: {
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(presentation.health.tint)
            }
            .buttonStyle(.plain)
        }
    }
}
