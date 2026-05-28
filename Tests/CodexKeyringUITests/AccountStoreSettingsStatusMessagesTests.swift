import XCTest
@testable import CodexKeyringUI

final class AccountStoreSettingsStatusMessagesTests: XCTestCase {
    func testSettingsAndExportMessagesStayCentralized() {
        let destination = URL(fileURLWithPath: "/tmp/codex-keyring.log")

        XCTAssertEqual(
            AccountStoreStatusMessages.restartCodexAppAfterSwitch(enabled: false),
            "Codex App restart after switching disabled."
        )
        XCTAssertEqual(
            AccountStoreStatusMessages.allowNetworkQuotaAPIs(enabled: true),
            "Network quota API calls enabled."
        )
        XCTAssertEqual(
            AccountStoreStatusMessages.quotaRefreshInterval(minutes: 30),
            "Quota refresh interval set to every 30 minutes."
        )
        XCTAssertEqual(
            AccountStoreStatusMessages.preserveAgentPreferencesPerAccount(enabled: true),
            "Per-account agent settings will be remembered (requires restart Codex App on switch)."
        )
        XCTAssertEqual(
            AccountStoreStatusMessages.launchAtLogin(enabled: true),
            "Launch at login enabled."
        )
        XCTAssertEqual(
            AccountStoreStatusMessages.logExport(destination: destination),
            "Logs exported to /tmp/codex-keyring.log."
        )
    }
}
