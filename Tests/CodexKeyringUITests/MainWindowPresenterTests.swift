import XCTest
@testable import CodexKeyringUI

final class MainWindowPresenterTests: XCTestCase {
    @MainActor
    func testManagerWindowIdentityMatchesSceneIDOrTitle() {
        XCTAssertTrue(
            MainWindowPresenter.isManagerWindow(
                identifier: MainWindowPresenter.windowID,
                title: "Different Title"
            )
        )
        XCTAssertTrue(
            MainWindowPresenter.isManagerWindow(
                identifier: nil,
                title: MainWindowPresenter.windowTitle
            )
        )
        XCTAssertFalse(
            MainWindowPresenter.isManagerWindow(
                identifier: "other",
                title: "Other Window"
            )
        )
    }
}
