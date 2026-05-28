import XCTest
@testable import CodexKeyringUI

final class EmptyAccountsPresentationTests: XCTestCase {
    func testEmptyAccountsPresentationPrioritizesSavingCurrentAuth() {
        let presentation = EmptyAccountsPresentation(
            canSaveCurrentAuth: true,
            canAddCurrentLogin: false,
            isLoginInProgress: false,
            canLoginNewAccount: true,
            canImportAccount: true
        )

        XCTAssertTrue(presentation.showsSaveCurrentLogin)
        XCTAssertFalse(presentation.canSaveCurrentLogin)
        XCTAssertFalse(presentation.usesProminentAddLoginButton)
        XCTAssertEqual(presentation.addLoginSystemImage, "person.badge.plus")
        XCTAssertTrue(presentation.canAddLogin)
        XCTAssertTrue(presentation.canImport)
    }

    func testEmptyAccountsPresentationPromotesLoginWhenNoCurrentAuthCanBeSaved() {
        let presentation = EmptyAccountsPresentation(
            canSaveCurrentAuth: false,
            canAddCurrentLogin: false,
            isLoginInProgress: true,
            canLoginNewAccount: false,
            canImportAccount: false
        )

        XCTAssertFalse(presentation.showsSaveCurrentLogin)
        XCTAssertTrue(presentation.usesProminentAddLoginButton)
        XCTAssertEqual(presentation.addLoginSystemImage, "hourglass")
        XCTAssertFalse(presentation.canAddLogin)
        XCTAssertFalse(presentation.canImport)
    }
}
