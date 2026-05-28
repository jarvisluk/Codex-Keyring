import XCTest
@testable import CodexKeyringUI

final class QuotaWindowPresentationTests: XCTestCase {
    func testQuotaWindowPresentationCarriesReadyVisualState() {
        let presentation = QuotaWindowPresentation(
            window: makeQuotaWindow(usedPercent: 60)
        )

        XCTAssertEqual(presentation.durationLabel, "5-hour")
        XCTAssertEqual(presentation.remainingText, "40% left")
        XCTAssertEqual(presentation.remainingPercent, 40)
        XCTAssertEqual(presentation.resetText, "reset unknown")
        XCTAssertEqual(presentation.remainingTextTint, .secondary)
        XCTAssertEqual(presentation.progressTint, .ready)
    }

    func testQuotaWindowPresentationSeparatesLowAndBlockedVisualState() {
        let low = QuotaWindowPresentation(
            window: makeQuotaWindow(usedPercent: 90)
        )
        let blocked = QuotaWindowPresentation(
            window: makeQuotaWindow(usedPercent: 96)
        )

        XCTAssertEqual(low.remainingTextTint, .low)
        XCTAssertEqual(low.progressTint, .low)
        XCTAssertEqual(blocked.remainingTextTint, .low)
        XCTAssertEqual(blocked.progressTint, .blocked)
    }
}
