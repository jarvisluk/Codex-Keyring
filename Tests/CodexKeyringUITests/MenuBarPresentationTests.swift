import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class MenuBarPresentationTests: XCTestCase {
    func testMenuBarAccountPresentationCapsLongDisplayName() {
        let account = makePresentationAccount(alias: "abcdefghijklmnopqrstuvwxyz1234567890")

        let presentation = MenuBarAccountPresentation(account: account)

        XCTAssertEqual(presentation.title, "abcdefghijklmnopqrstuvwxyz1...")
    }

    func testMenuBarAccountPresentationReflectsActiveState() {
        let account = makePresentationAccount(alias: "Work")

        let inactive = MenuBarAccountPresentation(account: account, isActive: false)
        let active = MenuBarAccountPresentation(account: account, isActive: true, canSwitch: false)

        XCTAssertEqual(inactive.statusSystemImage, "person.crop.circle")
        XCTAssertEqual(inactive.statusIconTint, .secondary)
        XCTAssertTrue(inactive.canSwitch)
        XCTAssertEqual(active.statusSystemImage, "checkmark.circle.fill")
        XCTAssertEqual(active.statusIconTint, .active)
        XCTAssertFalse(active.canSwitch)
    }

    func testMenuBarQuotaPresentationUsesVisibleSummaryAndHealth() throws {
        let accountID = UUID()
        let errorState = AccountQuotaState.error(
            accountID: accountID,
            message: "Could not refresh quota",
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let idleState = AccountQuotaState(accountID: accountID, phase: .idle)

        let presentation = try XCTUnwrap(MenuBarQuotaPresentation(state: errorState))

        XCTAssertEqual(presentation.title, "quota error")
        XCTAssertEqual(presentation.health, .error)
        XCTAssertNil(MenuBarQuotaPresentation(state: idleState))
    }

    func testAppMenuBarPresentationReflectsActiveAccountState() {
        let inactive = AppMenuBarPresentation(activeAccount: nil)
        let active = AppMenuBarPresentation(activeAccount: makePresentationAccount(alias: "Work"))

        XCTAssertEqual(inactive.systemImage, "person.crop.circle.badge.questionmark")
        XCTAssertEqual(inactive.statusLabel, "Codex Keyring: no active saved account")
        XCTAssertEqual(active.systemImage, "person.crop.circle.badge.checkmark")
        XCTAssertEqual(active.statusLabel, "Codex Keyring: Work active")
    }
}
