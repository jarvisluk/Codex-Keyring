import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountStoreSaveImportStatusMessagesTests: XCTestCase {
    func testAddAccountIncludesAgentPreferencesWarning() {
        let result = AddAccountResult(
            state: .empty,
            savedAlias: "Personal",
            wasUpdate: false,
            agentPreferencesWarningReason: "config denied"
        )

        let message = AccountStoreStatusMessages.addAccount(
            base: "Saved current Codex auth as Personal.",
            result: result
        )

        XCTAssertEqual(
            message,
            "Saved current Codex auth as Personal. Agent settings were not saved for this account: config denied"
        )
    }

    func testCurrentAuthAlreadySavedNamesSavedAccount() {
        XCTAssertEqual(
            AccountStoreStatusMessages.currentAuthAlreadySaved(displayName: "Work"),
            "Current Codex auth is already saved as Work."
        )
    }
}
