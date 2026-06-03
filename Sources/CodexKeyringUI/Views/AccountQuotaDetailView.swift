import SwiftUI
import CodexKeyringDomain

struct AccountQuotaDetailView: View {
    @EnvironmentObject private var store: AccountStore

    let account: CodexAccount

    private var presentation: AccountQuotaDetailPresentation {
        AccountQuotaDetailPresentation(
            allowNetworkQuotaAPIs: store.settings.allowNetworkQuotaAPIs,
            quotaState: store.quotaStates[account.id],
            canRefreshQuotas: store.canRefreshQuotas
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.section) {
            HStack {
                KeyringSectionHeader("Quota", systemImage: "gauge.medium")
                Spacer()
                Button {
                    store.refreshQuotasNow()
                } label: {
                    Label("Refresh Quotas", systemImage: "arrow.clockwise")
                }
                .disabled(!presentation.canRefreshQuotas)
            }

            switch presentation.content {
            case let .networkDisabled(message):
                Text(message)
                    .foregroundStyle(.secondary)
            case let .quotaState(state):
                AccountQuotaStateContentView(state: state)
            case let .notRefreshed(message):
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }
        .keyringSurface(.regular)
        .frame(maxWidth: KeyringStyle.Layout.quotaDetailMaxWidth, alignment: .leading)
    }
}
