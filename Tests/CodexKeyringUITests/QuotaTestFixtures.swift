import Foundation
@testable import CodexKeyringDomain

func makeQuotaWindow(
    usedPercent: Double,
    durationMinutes: Int = 5 * 60
) -> QuotaWindow {
    QuotaWindow(
        usedPercent: usedPercent,
        windowDurationMinutes: durationMinutes,
        resetsAt: nil
    )
}

func makeQuotaSnapshot(
    accountID: UUID = UUID(),
    planType: String = "plus",
    email: String = "person@example.com",
    fetchedAt: Date = Date(timeIntervalSince1970: 1),
    limitName: String? = nil,
    windows: [QuotaWindow] = [],
    endpoint: String? = nil
) -> AccountQuotaSnapshot {
    AccountQuotaSnapshot(
        accountID: accountID,
        planType: planType,
        email: email,
        fetchedAt: fetchedAt,
        buckets: [
            QuotaBucket(
                limitID: "codex",
                limitName: limitName,
                planType: planType,
                windows: windows,
                credits: nil,
                rateLimitReachedType: nil
            )
        ],
        endpoint: endpoint
    )
}

func makeAvailableQuotaState(
    accountID: UUID = UUID(),
    planType: String = "plus",
    limitName: String? = nil,
    windows: [QuotaWindow] = []
) -> AccountQuotaState {
    .available(
        makeQuotaSnapshot(
            accountID: accountID,
            planType: planType,
            limitName: limitName,
            windows: windows
        )
    )
}
