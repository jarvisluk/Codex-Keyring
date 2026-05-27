import XCTest
@testable import CodexKeyringUI

final class MenuBarStatusPresentationTests: XCTestCase {
    func testReadyStatusIsHidden() {
        let presentation = MenuBarStatusPresentation.make(
            statusMessage: "Ready.",
            lastError: nil,
            isBusy: false
        )

        XCTAssertNil(presentation)
    }

    func testBusyStatusIsShown() throws {
        let presentation = try XCTUnwrap(MenuBarStatusPresentation.make(
            statusMessage: "Refreshing account state...",
            lastError: nil,
            isBusy: true
        ))

        XCTAssertEqual(presentation.title, "Refreshing account state...")
        XCTAssertEqual(presentation.help, "Refreshing account state...")
        XCTAssertEqual(presentation.systemImage, "hourglass")
        XCTAssertFalse(presentation.isError)
    }

    func testRecentNonReadyStatusIsShown() throws {
        let presentation = try XCTUnwrap(MenuBarStatusPresentation.make(
            statusMessage: "Switched Codex CLI auth to work.",
            lastError: nil,
            isBusy: false
        ))

        XCTAssertEqual(presentation.title, "Switched Codex CLI auth to...")
        XCTAssertEqual(presentation.help, "Switched Codex CLI auth to work.")
        XCTAssertEqual(presentation.systemImage, "checkmark.circle")
        XCTAssertFalse(presentation.isError)
    }

    func testErrorTakesPriorityAndKeepsFullHelpText() throws {
        let error = "Local storage operation failed: permission denied"
        let presentation = try XCTUnwrap(MenuBarStatusPresentation.make(
            statusMessage: "Refreshing account quotas...",
            lastError: error,
            isBusy: true
        ))

        XCTAssertEqual(presentation.title, "Local storage operation fai...")
        XCTAssertEqual(presentation.help, error)
        XCTAssertEqual(presentation.systemImage, "exclamationmark.triangle.fill")
        XCTAssertTrue(presentation.isError)
    }
}
