import XCTest
@testable import CodexKeyringUI

final class AccountStorePreferenceCapabilitiesTests: XCTestCase {
    func testPreferenceEditsOnlyFollowQueuedOperationState() {
        let busyCapabilities = makeAccountStoreCapabilities(isOperationInProgress: true)

        XCTAssertFalse(busyCapabilities.canEditPreferences)
        XCTAssertFalse(busyCapabilities.canSetRestartCodexAppAfterSwitch(to: false))
        XCTAssertFalse(busyCapabilities.canSetAllowNetworkQuotaAPIs(to: true))
        XCTAssertFalse(busyCapabilities.canSetQuotaRefreshInterval(to: 5))
        XCTAssertFalse(busyCapabilities.canSetShowDockIcon(to: false))

        let idleCapabilities = makeAccountStoreCapabilities(
            settings: quotaEnabledSettings(),
            isLaunchAtLoginSupported: true
        )

        XCTAssertTrue(idleCapabilities.canEditPreferences)
        XCTAssertTrue(idleCapabilities.canSetRestartCodexAppAfterSwitch(to: false))
        XCTAssertTrue(idleCapabilities.canSetAllowNetworkQuotaAPIs(to: false))
        XCTAssertTrue(idleCapabilities.canSetQuotaRefreshInterval(to: 5))
        XCTAssertTrue(idleCapabilities.canSetLaunchAtLogin(to: true))
        XCTAssertTrue(idleCapabilities.canSetShowDockIcon(to: false))
    }
}
