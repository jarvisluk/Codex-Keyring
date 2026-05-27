import XCTest
@testable import CodexKeyringUI

final class MainWindowRequestTests: XCTestCase {
    func testStartNewLoginPostsExpectedNotification() {
        let notificationCenter = NotificationCenter()
        let expectation = expectation(description: "start new login")
        let observer = notificationCenter.addObserver(
            forName: .codexKeyringStartNewLogin,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { notificationCenter.removeObserver(observer) }

        MainWindowRequest.startNewLogin(notificationCenter: notificationCenter)

        wait(for: [expectation], timeout: 0.1)
    }

    func testShowAddCurrentLoginSheetPostsExpectedNotification() {
        let notificationCenter = NotificationCenter()
        let expectation = expectation(description: "add current login")
        let observer = notificationCenter.addObserver(
            forName: .codexKeyringShowAddCurrentLoginSheet,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { notificationCenter.removeObserver(observer) }

        MainWindowRequest.showAddCurrentLoginSheet(notificationCenter: notificationCenter)

        wait(for: [expectation], timeout: 0.1)
    }

    func testImportAuthSnapshotPostsExpectedNotification() {
        let notificationCenter = NotificationCenter()
        let expectation = expectation(description: "import auth snapshot")
        let observer = notificationCenter.addObserver(
            forName: .codexKeyringImportAuthSnapshot,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { notificationCenter.removeObserver(observer) }

        MainWindowRequest.importAuthSnapshot(notificationCenter: notificationCenter)

        wait(for: [expectation], timeout: 0.1)
    }

    @MainActor
    func testRunAfterCurrentMainActorTurnDefersAction() async {
        let actionRan = expectation(description: "deferred action ran")
        var didRunImmediately = false

        MainWindowRequest.runAfterCurrentMainActorTurn {
            didRunImmediately = true
            actionRan.fulfill()
        }

        XCTAssertFalse(didRunImmediately)
        await fulfillment(of: [actionRan], timeout: 1)
        XCTAssertTrue(didRunImmediately)
    }
}
