import XCTest
@testable import CodexKeyringDomain

final class AccountQuotaTests: XCTestCase {
    func testBucketDisplayIdentityIgnoresBlankNames() {
        let bucket = QuotaBucket(
            limitID: " codex ",
            limitName: " \n ",
            planType: "plus",
            windows: [
                QuotaWindow(usedPercent: 50, windowDurationMinutes: 5 * 60, resetsAt: nil)
            ],
            credits: nil,
            rateLimitReachedType: nil
        )

        XCTAssertEqual(bucket.id, "codex")
        XCTAssertEqual(bucket.displayName, "codex")
    }

    func testWhitespaceReachedTypeDoesNotBlockUnmeteredPlan() {
        let bucket = QuotaBucket(
            limitID: "codex",
            limitName: nil,
            planType: " business ",
            windows: [],
            credits: nil,
            rateLimitReachedType: " \n "
        )

        XCTAssertTrue(bucket.isUnlimited)
        XCTAssertEqual(bucket.health, .ready)
    }

    func testPrimaryBucketMatchesTrimmedCodexIdentifier() {
        let fallback = QuotaBucket(
            limitID: "other",
            limitName: "Other",
            planType: "plus",
            windows: [
                QuotaWindow(usedPercent: 10, windowDurationMinutes: 5 * 60, resetsAt: nil)
            ],
            credits: nil,
            rateLimitReachedType: nil
        )
        let codex = QuotaBucket(
            limitID: " CODEX ",
            limitName: nil,
            planType: "plus",
            windows: [
                QuotaWindow(usedPercent: 20, windowDurationMinutes: 5 * 60, resetsAt: nil)
            ],
            credits: nil,
            rateLimitReachedType: nil
        )
        let snapshot = AccountQuotaSnapshot(
            accountID: UUID(),
            planType: "plus",
            email: "person@example.com",
            fetchedAt: Date(timeIntervalSince1970: 1),
            buckets: [fallback, codex],
            endpoint: nil
        )

        XCTAssertEqual(snapshot.primaryBucket?.id, "CODEX")
        XCTAssertEqual(snapshot.health, codex.health)
    }
}
