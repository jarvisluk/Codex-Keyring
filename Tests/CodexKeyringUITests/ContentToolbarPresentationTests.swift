import XCTest
@testable import CodexKeyringUI

final class ContentToolbarPresentationTests: XCTestCase {
    func testContentToolbarPresentationEnablesIdleActions() {
        let presentation = ContentToolbarPresentation(
            isSettingsPresented: false,
            isLoginInProgress: false,
            isRefreshInProgress: false,
            canLoginNewAccount: true,
            canImportAccount: true,
            canRefreshAccounts: true
        )

        XCTAssertEqual(presentation.addLoginTitle, "Add Login")
        XCTAssertEqual(presentation.addLoginSystemImage, "plus.circle")
        XCTAssertFalse(presentation.addLoginCancelsInProgress)
        XCTAssertTrue(presentation.canAddLogin)
        XCTAssertTrue(presentation.canImport)
        XCTAssertTrue(presentation.canRefresh)
        XCTAssertFalse(presentation.isRefreshLoading)
    }

    func testContentToolbarPresentationDisablesActionsBehindSettingsWindow() {
        let presentation = ContentToolbarPresentation(
            isSettingsPresented: true,
            isLoginInProgress: false,
            isRefreshInProgress: false,
            canLoginNewAccount: true,
            canImportAccount: true,
            canRefreshAccounts: true
        )

        XCTAssertEqual(presentation.addLoginTitle, "Add Login")
        XCTAssertEqual(presentation.addLoginSystemImage, "plus.circle")
        XCTAssertFalse(presentation.addLoginCancelsInProgress)
        XCTAssertFalse(presentation.canAddLogin)
        XCTAssertFalse(presentation.canImport)
        XCTAssertFalse(presentation.canRefresh)
        XCTAssertFalse(presentation.isRefreshLoading)
    }

    func testContentToolbarPresentationTurnsLoginActionIntoCancel() {
        let presentation = ContentToolbarPresentation(
            isSettingsPresented: false,
            isLoginInProgress: true,
            isRefreshInProgress: true,
            canLoginNewAccount: false,
            canImportAccount: true,
            canRefreshAccounts: true
        )

        XCTAssertEqual(presentation.addLoginTitle, "Cancel Login")
        XCTAssertEqual(presentation.addLoginSystemImage, "xmark.circle")
        XCTAssertTrue(presentation.addLoginCancelsInProgress)
        XCTAssertTrue(presentation.canAddLogin)
        XCTAssertTrue(presentation.canImport)
        XCTAssertTrue(presentation.canRefresh)
        XCTAssertTrue(presentation.isRefreshLoading)
    }
}
