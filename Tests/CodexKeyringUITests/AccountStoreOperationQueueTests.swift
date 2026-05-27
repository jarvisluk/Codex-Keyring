import XCTest
@testable import CodexKeyringUI

@MainActor
final class AccountStoreOperationQueueTests: XCTestCase {
    func testEnqueuedOperationsRunSeriallyInOrder() async {
        let queue = AccountStoreOperationQueue()
        let firstOperationStarted = expectation(description: "first operation started")
        let done = expectation(description: "second operation finished")
        var events: [String] = []
        var finishFirstOperation: CheckedContinuation<Void, Never>?

        queue.enqueue {
            events.append("first-start")
            firstOperationStarted.fulfill()
            await withCheckedContinuation { continuation in
                finishFirstOperation = continuation
            }
            events.append("first-end")
        }
        queue.enqueue {
            events.append("second")
            done.fulfill()
        }

        await fulfillment(of: [firstOperationStarted], timeout: 1)
        XCTAssertEqual(events, ["first-start"])

        finishFirstOperation?.resume()
        await fulfillment(of: [done], timeout: 1)
        XCTAssertEqual(events, ["first-start", "first-end", "second"])
    }

    func testFailureHandlerRunsAndQueueContinues() async {
        enum TestError: Error {
            case boom
        }

        let queue = AccountStoreOperationQueue()
        let done = expectation(description: "second operation finished")
        var events: [String] = []

        queue.enqueue {
            events.append("first")
            throw TestError.boom
        } onFailure: { error in
            if case TestError.boom = error {
                events.append("failed")
            }
        }

        queue.enqueue {
            events.append("second")
            done.fulfill()
        }

        await fulfillment(of: [done], timeout: 1)
        XCTAssertEqual(events, ["first", "failed", "second"])
    }
}
