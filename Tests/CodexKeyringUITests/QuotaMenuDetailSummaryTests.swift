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
}
