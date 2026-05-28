import XCTest
@testable import CodexKeyringUI

final class QuotaSidebarSummaryTests: XCTestCase {
    func testSidebarSummaryShowsUnlimitedLimitWindows() {
        let state = makeAvailableQuotaState(planType: "business")

        XCTAssertEqual(state.sidebarSummary, "5h unlimited · week unlimited")
    }

    func testSidebarSummaryShowsFiveHourAndWeeklyWindows() {
        let state = makeAvailableQuotaState(
            windows: [
                makeQuotaWindow(usedPercent: 12, durationMinutes: 7 * 24 * 60),
                makeQuotaWindow(usedPercent: 3)
            ]
        )

        XCTAssertEqual(state.sidebarSummary, "5h 97% left · week 88% left")
    }
}
