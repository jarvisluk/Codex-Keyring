import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountDetailPresentationTests: XCTestCase {
    func testAccountDetailMetadataPresentationTrimsVisibleMetadata() {
        let account = makePresentationAccount(
            plan: "  Plus  ",
            authMode: "  chatgpt  ",
            accountIdentifier: "  acct-123  ",
            fingerprint: "abcdef1234567890"
        )

        let presentation = AccountDetailMetadataPresentation(account: account)

        XCTAssertEqual(presentation.authMode, "chatgpt")
        XCTAssertEqual(presentation.plan, "Plus")
        XCTAssertEqual(presentation.accountIdentifier, "acct-123")
        XCTAssertEqual(presentation.fingerprint, "abcdef1234")
    }

    func testAccountDetailRenameStateTrimsAndResetsAlias() {
        var state = AccountDetailRenameState()

        state.begin(alias: "  Personal  ")

        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.cleanedDraft, "Personal")

        state.sync(alias: "Work")
        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.draft, "Work")

        state.cancel()
        XCTAssertFalse(state.isPresented)

        state.begin(alias: "Old")
        state.reset(alias: "New")
        XCTAssertFalse(state.isPresented)
        XCTAssertEqual(state.draft, "New")
    }

    func testAccountDetailActionPresentationReflectsSwitchMode() {
        let inactiveRestarting = AccountDetailActionPresentation(
            isActive: false,
            restartCodexAppAfterSwitch: true
        )
        let activeCliOnly = AccountDetailActionPresentation(
            isActive: true,
            restartCodexAppAfterSwitch: false
        )

        XCTAssertEqual(inactiveRestarting.switchTitle, "Switch")
        XCTAssertTrue(inactiveRestarting.switchHelpText.contains("restart Codex App"))
        XCTAssertEqual(activeCliOnly.switchTitle, "Switch Again")
        XCTAssertTrue(activeCliOnly.switchHelpText.contains("Codex CLI auth only"))
    }

    func testAccountDetailActionAvailabilityCarriesButtonStates() {
        let availability = AccountDetailActionAvailability(
            canSubmitAliasRename: true,
            canSwitch: false,
            canBeginRename: true,
            canRemove: false
        )

        XCTAssertTrue(availability.canSubmitAliasRename)
        XCTAssertFalse(availability.canSwitch)
        XCTAssertTrue(availability.canBeginRename)
        XCTAssertFalse(availability.canRemove)
    }
}
