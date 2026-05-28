import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountStoreSwitchStatusMessagesTests: XCTestCase {
    func testSwitchAccountCombinesRestartAndPreferenceWarnings() {
        let result = SwitchAccountResult(
            state: .empty,
            switchedAlias: "Work",
            restartOutcome: .relaunched,
            restartFailureReason: nil,
            wasAlreadyActive: false,
            appliedAgentPreferences: true,
            agentPreferencesWarningReason: "config denied",
            projectArrangementWarningReason: "global state denied"
        )

        let message = AccountStoreStatusMessages.switchAccount(
            result: result,
            restartWasRequested: true
        )

        XCTAssertEqual(
            message,
            "Codex App was restarted so it can reload the switched auth state. Restored saved agent settings for this account. Agent settings could not be fully updated: config denied Codex project list layout could not be preserved: global state denied"
        )
    }
}
