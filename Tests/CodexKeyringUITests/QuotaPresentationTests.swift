import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class QuotaPresentationTests: XCTestCase {
    func testMenuDetailSummaryPrefersPrimaryQuotaWindows() throws {
        let accountID = UUID()
        let snapshot = AccountQuotaSnapshot(
            accountID: accountID,
            planType: "plus",
            email: "person@example.com",
            fetchedAt: Date(timeIntervalSince1970: 1),
            buckets: [
                QuotaBucket(
                    limitID: "codex",
                    limitName: "Codex",
                    planType: "plus",
                    windows: [
                        QuotaWindow(usedPercent: 20, windowDurationMinutes: 24 * 60, resetsAt: nil),
                        QuotaWindow(usedPercent: 1, windowDurationMinutes: 5 * 60, resetsAt: nil),
                        QuotaWindow(usedPercent: 2, windowDurationMinutes: 7 * 24 * 60, resetsAt: nil),
                    ],
                    credits: nil,
                    rateLimitReachedType: nil
                ),
            ],
            endpoint: "https://example.test/quota"
        )

        let summary = try XCTUnwrap(AccountQuotaState.available(snapshot).menuDetailSummary)

        XCTAssertEqual(summary, "5h 99% left · week 98% left")
        XCTAssertLessThanOrEqual(summary.count, 30)
    }

    func testMenuDetailSummaryCapsLongQuotaWindowLabels() throws {
        let accountID = UUID()
        let snapshot = AccountQuotaSnapshot(
            accountID: accountID,
            planType: "plus",
            email: "person@example.com",
            fetchedAt: Date(timeIntervalSince1970: 1),
            buckets: [
                QuotaBucket(
                    limitID: "codex",
                    limitName: "Codex",
                    planType: "plus",
                    windows: [
                        QuotaWindow(usedPercent: 1, windowDurationMinutes: nil, resetsAt: nil),
                        QuotaWindow(usedPercent: 2, windowDurationMinutes: 4_321, resetsAt: nil),
                        QuotaWindow(usedPercent: 3, windowDurationMinutes: 8_642, resetsAt: nil),
                    ],
                    credits: nil,
                    rateLimitReachedType: nil
                ),
            ],
            endpoint: "https://example.test/quota"
        )

        let summary = try XCTUnwrap(AccountQuotaState.available(snapshot).menuDetailSummary)

        XCTAssertLessThanOrEqual(summary.count, 30)
        XCTAssertTrue(summary.hasSuffix("..."))
    }
}
