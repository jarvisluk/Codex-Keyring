import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class QuotaMenuDetailSummaryTests: XCTestCase {
    func testMenuDetailSummaryPrefersTwoCompactWindows() throws {
        let snapshot = makeQuotaSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 0),
            limitName: "Codex",
            windows: [
                makeQuotaWindow(usedPercent: 80, durationMinutes: 24 * 60),
                makeQuotaWindow(usedPercent: 1),
                makeQuotaWindow(usedPercent: 2, durationMinutes: 7 * 24 * 60)
            ]
        )

        let summary = try XCTUnwrap(AccountQuotaState.available(snapshot).menuDetailSummary)

        XCTAssertEqual(summary, "5h 99% left · week 98% left")
    }

    func testMenuDetailSummaryAppendsResetCreditExpiration() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = makeQuotaSnapshot(
            fetchedAt: now,
            limitName: "Codex",
            windows: [
                makeQuotaWindow(usedPercent: 1)
            ],
            rateLimitResetCredits: AccountRateLimitResetCredits(
                availableCount: 1,
                credits: [
                    RateLimitResetCredit(
                        id: "credit-1",
                        title: nil,
                        description: nil,
                        status: "available",
                        expiresAt: now.addingTimeInterval((9 * 86_400) + (6 * 3_600)),
                        profileUserID: nil,
                        profileImageURL: nil
                    )
                ],
                fetchedAt: now,
                endpoint: nil
            )
        )

        let summary = try XCTUnwrap(
            AccountQuotaState.available(snapshot).menuDetailSummary(now: now)
        )

        XCTAssertEqual(summary, "5h 99% left · reset 9d 6h")
    }
}
