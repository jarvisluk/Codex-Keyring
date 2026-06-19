import XCTest
@testable import CodexKeyringUI

final class QuotaSidebarSummaryTests: XCTestCase {
    func testSidebarSummaryShowsUnlimitedLimitWindows() {
        let state = makeAvailableQuotaState(planType: "business")

        XCTAssertEqual(state.sidebarSummary, "5h unlimited · week unlimited")
        XCTAssertEqual(state.compactSidebarSummary, "unlimited")
    }

    func testSidebarSummaryShowsFiveHourAndWeeklyWindows() {
        let state = makeAvailableQuotaState(
            windows: [
                makeQuotaWindow(usedPercent: 12, durationMinutes: 7 * 24 * 60),
                makeQuotaWindow(usedPercent: 3)
            ]
        )

        XCTAssertEqual(state.sidebarSummary, "5h 97% left · week 88% left")
        XCTAssertEqual(state.compactSidebarSummary, "5h 97% · week 88%")
    }

    func testSidebarSummaryShowsWeeklyAndMonthlyWindows() {
        let state = makeAvailableQuotaState(
            windows: [
                makeQuotaWindow(usedPercent: 5, durationMinutes: 30 * 24 * 60),
                makeQuotaWindow(usedPercent: 12, durationMinutes: 7 * 24 * 60)
            ]
        )

        XCTAssertEqual(state.sidebarSummary, "week 88% left · monthly 95% left")
        XCTAssertEqual(state.compactSidebarSummary, "week 88% · monthly 95%")
    }
}
