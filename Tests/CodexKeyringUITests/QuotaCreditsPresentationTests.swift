import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class QuotaCreditsPresentationTests: XCTestCase {
    func testQuotaCreditsPresentationCarriesVisibleCreditState() {
        let regular = QuotaCreditsPresentation(
            credits: QuotaCredits(balance: "25", hasCredits: true, unlimited: false)
        )
        let unlimited = QuotaCreditsPresentation(
            credits: QuotaCredits(balance: nil, hasCredits: true, unlimited: true)
        )

        XCTAssertTrue(regular.isVisible)
        XCTAssertEqual(regular.label, "Credits: 25")
        XCTAssertEqual(regular.systemImage, "creditcard")
        XCTAssertEqual(regular.tint, .secondary)
        XCTAssertTrue(unlimited.isVisible)
        XCTAssertEqual(unlimited.label, "Credits: unlimited")
        XCTAssertEqual(unlimited.systemImage, "creditcard")
        XCTAssertEqual(unlimited.tint, .secondary)
    }

    func testQuotaCreditsPresentationCarriesHiddenAndDepletedState() {
        let hidden = QuotaCreditsPresentation(
            credits: QuotaCredits(balance: nil, hasCredits: false, unlimited: false)
        )
        let depleted = QuotaCreditsPresentation(
            credits: QuotaCredits(balance: "0", hasCredits: true, unlimited: false)
        )

        XCTAssertFalse(hidden.isVisible)
        XCTAssertTrue(depleted.isVisible)
        XCTAssertEqual(depleted.label, "Credits: 0")
        XCTAssertEqual(depleted.systemImage, "creditcard.trianglebadge.exclamationmark")
        XCTAssertEqual(depleted.tint, .depleted)
    }
}
