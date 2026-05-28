import XCTest
@testable import CodexKeyringUI

final class AccountLiveAuthSyncCoalescerTests: XCTestCase {
    func testFirstRequestStartsSync() {
        var coalescer = AccountLiveAuthSyncCoalescer()

        XCTAssertEqual(coalescer.requestSync(), .start)
    }

    func testRequestWhileScheduledCoalescesSingleFollowUp() {
        var coalescer = AccountLiveAuthSyncCoalescer()

        XCTAssertEqual(coalescer.requestSync(), .start)
        XCTAssertEqual(coalescer.requestSync(), .coalesce)
        XCTAssertEqual(coalescer.requestSync(), .coalesce)

        XCTAssertTrue(coalescer.finishSync())
        XCTAssertEqual(coalescer.requestSync(), .start)
    }

    func testFinishWithoutCoalescedRequestDoesNotRequestFollowUp() {
        var coalescer = AccountLiveAuthSyncCoalescer()

        XCTAssertEqual(coalescer.requestSync(), .start)
        XCTAssertFalse(coalescer.finishSync())
        XCTAssertEqual(coalescer.requestSync(), .start)
    }
}
