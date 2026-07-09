import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class RateLimitResetCreditsPresentationTests: XCTestCase {
    func testPresentationShowsAvailableCountAndEarliestExpiration() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let resetCredits = AccountRateLimitResetCredits(
            availableCount: 1,
            credits: [
                RateLimitResetCredit(
                    id: "credit-1",
                    title: "Rate limit reset",
                    description: nil,
                    status: "available",
                    expiresAt: now.addingTimeInterval((30 * 86_400) + (2 * 3_600)),
                    profileUserID: nil,
                    profileImageURL: nil
                )
            ],
            fetchedAt: now,
            endpoint: nil
        )

        let presentation = RateLimitResetCreditsPresentation(
            resetCredits: resetCredits,
            now: now
        )

        XCTAssertTrue(presentation.isVisible)
        XCTAssertEqual(presentation.summaryText, "1 reset available")
        XCTAssertEqual(presentation.expirationText, "Earliest expires in 30d 2h")
        XCTAssertNotNil(presentation.exactExpirationText)
        XCTAssertEqual(presentation.rows.map(\.title), ["Rate limit reset"])
        XCTAssertEqual(presentation.rows.map(\.expirationText), ["30d 2h"])
    }

    func testPresentationDoesNotInventExpirationWhenDetailsAreUnavailable() {
        let resetCredits = AccountRateLimitResetCredits(
            availableCount: 2,
            credits: [],
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            endpoint: nil
        )

        let presentation = RateLimitResetCreditsPresentation(resetCredits: resetCredits)

        XCTAssertTrue(presentation.isVisible)
        XCTAssertEqual(presentation.summaryText, "2 resets available")
        XCTAssertEqual(presentation.expirationText, "Expiration unavailable")
        XCTAssertNil(presentation.exactExpirationText)
        XCTAssertTrue(presentation.rows.isEmpty)
    }

    func testCompactMenuSummaryUsesEarliestAvailableCredit() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let resetCredits = AccountRateLimitResetCredits(
            availableCount: 2,
            credits: [
                RateLimitResetCredit(
                    id: "redeemed",
                    title: nil,
                    description: nil,
                    status: "redeemed",
                    expiresAt: now.addingTimeInterval(86_400),
                    profileUserID: nil,
                    profileImageURL: nil
                ),
                RateLimitResetCredit(
                    id: "available",
                    title: nil,
                    description: nil,
                    status: "available",
                    expiresAt: now.addingTimeInterval((4 * 86_400) + 3_600),
                    profileUserID: nil,
                    profileImageURL: nil
                )
            ],
            fetchedAt: now,
            endpoint: nil
        )

        XCTAssertEqual(resetCredits.compactMenuSummary(now: now), "reset 4d 1h")
    }
}
