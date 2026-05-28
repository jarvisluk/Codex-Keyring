import CodexKeyringDomain

struct MenuBarQuotaPresentation: Equatable {
    let title: String
    let health: QuotaHealth

    init?(state: AccountQuotaState) {
        guard let title = state.menuDetailSummary else { return nil }
        self.title = title
        health = state.health
    }
}
