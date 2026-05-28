import XCTest
@testable import CodexKeyringUI

final class SidebarStatusPresentationTests: XCTestCase {
    func testSidebarStatusPresentationReflectsErrorState() {
        let presentation = SidebarStatusPresentation(
            statusMessage: "Could not read auth.json",
            lastError: "Could not read auth.json",
            isBusy: true
        )

        XCTAssertEqual(presentation.indicator, .error)
        XCTAssertEqual(presentation.indicator.systemImage, "exclamationmark.triangle.fill")
        XCTAssertEqual(presentation.textTint, .error)
        XCTAssertEqual(presentation.lineLimit, 3)
        XCTAssertEqual(presentation.accessibilityLabel, "Status: Could not read auth.json")
    }

    func testSidebarStatusPresentationReflectsBusyAndReadyStates() {
        let busy = SidebarStatusPresentation(statusMessage: "Refreshing", lastError: nil, isBusy: true)
        let ready = SidebarStatusPresentation(statusMessage: "Ready.", lastError: nil, isBusy: false)

        XCTAssertEqual(busy.indicator, .busy)
        XCTAssertEqual(busy.textTint, .secondary)
        XCTAssertEqual(busy.lineLimit, 2)
        XCTAssertEqual(ready.indicator, .none)
        XCTAssertEqual(ready.textTint, .secondary)
        XCTAssertEqual(ready.lineLimit, 2)
    }
}
