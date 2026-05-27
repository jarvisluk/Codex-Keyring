import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class QuotaPresentationTests: XCTestCase {
    func testSidebarSummaryShowsUnlimitedLimitWindows() {
        let accountID = UUID()
        let state = AccountQuotaState.available(
            AccountQuotaSnapshot(
                accountID: accountID,
                planType: "business",
                email: "person@example.com",
                fetchedAt: Date(timeIntervalSince1970: 1),
                buckets: [
                    QuotaBucket(
                        limitID: "codex",
                        limitName: nil,
                        planType: "business",
                        windows: [],
                        credits: nil,
                        rateLimitReachedType: nil
                    )
                ],
                endpoint: nil
            )
        )

        XCTAssertEqual(state.sidebarSummary, "5h unlimited · week unlimited")
    }

    func testSidebarSummaryShowsFiveHourAndWeeklyWindows() {
        let accountID = UUID()
        let state = AccountQuotaState.available(
            AccountQuotaSnapshot(
                accountID: accountID,
                planType: "plus",
                email: "person@example.com",
                fetchedAt: Date(timeIntervalSince1970: 1),
                buckets: [
                    QuotaBucket(
                        limitID: "codex",
                        limitName: nil,
                        planType: "plus",
                        windows: [
                            QuotaWindow(usedPercent: 12, windowDurationMinutes: 7 * 24 * 60, resetsAt: nil),
                            QuotaWindow(usedPercent: 3, windowDurationMinutes: 5 * 60, resetsAt: nil)
                        ],
                        credits: nil,
                        rateLimitReachedType: nil
                    )
                ],
                endpoint: nil
            )
        )

        XCTAssertEqual(state.sidebarSummary, "5h 97% left · week 88% left")
    }
}
