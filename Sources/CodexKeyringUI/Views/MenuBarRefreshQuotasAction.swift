import SwiftUI

struct MenuBarRefreshQuotasAction: View {
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        Button("Refresh Quotas") {
            store.refreshQuotasNow()
        }
        .disabled(!store.canRefreshQuotas)
    }
}
