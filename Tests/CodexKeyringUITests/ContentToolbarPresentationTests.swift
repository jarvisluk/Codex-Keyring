import XCTest
@testable import CodexKeyringUI

final class ContentToolbarPresentationTests: XCTestCase {
    func testContentToolbarPresentationDisablesActionsBehindSettingsModal() {
        let presentation = ContentToolbarPresentation(
            isSettingsPresented: true,
            isLoginInProgress: false,
            isRefreshInProgress: false,
            canLoginNewAccount: true,
            canImportAccount: true,
            canRefreshAccounts: true
        )

        XCTAssertEqual(presentation.addLoginSystemImage, "plus.circle")
        XCTAssertFalse(presentation.canAddLogin)
        XCTAssertFalse(presentation.canImport)
        XCTAssertFalse(presentation.canRefresh)
        XCTAssertFalse(presentation.isRefreshLoading)
    }

    func testContentToolbarPresentationCarriesLoadingState() {
        let presentation = ContentToolbarPresentation(
            isSettingsPresented: false,
            isLoginInProgress: true,
            isRefreshInProgress: true,
            canLoginNewAccount: false,
            canImportAccount: true,
            canRefreshAccounts: true
        )

        XCTAssertEqual(presentation.addLoginSystemImage, "hourglass")
        XCTAssertFalse(presentation.canAddLogin)
        XCTAssertTrue(presentation.canImport)
        XCTAssertTrue(presentation.canRefresh)
        XCTAssertTrue(presentation.isRefreshLoading)
    }
}
