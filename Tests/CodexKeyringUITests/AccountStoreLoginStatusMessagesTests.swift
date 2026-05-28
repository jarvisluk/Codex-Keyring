import XCTest
@testable import CodexKeyringUI

final class AccountStoreLoginStatusMessagesTests: XCTestCase {
    func testLoginSuccessIncludesCleanupWarning() {
        let message = AccountStoreStatusMessages.loginSuccess(
            savedAlias: "Work",
            cleanupWarningReason: "permission denied"
        )

        XCTAssertEqual(
            message,
            "Saved new Codex login as Work. Current Codex auth was not switched. Temporary login files could not be cleaned up: permission denied"
        )
    }
}
