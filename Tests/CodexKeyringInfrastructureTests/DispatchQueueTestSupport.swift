import Foundation
import XCTest

extension XCTestCase {
    func blockSerialQueue(
        _ queue: DispatchQueue,
        description: String
    ) -> () -> Void {
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        queue.async {
            started.signal()
            release.wait()
        }
        let waitResult = started.wait(timeout: .now() + 1)
        XCTAssertEqual(waitResult, .success, "\(description) did not start.")
        return {
            release.signal()
        }
    }
}
