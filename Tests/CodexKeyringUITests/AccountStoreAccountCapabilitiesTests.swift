import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountStoreAccountCapabilitiesTests: XCTestCase {
    func testAccountWorkBusyStateDisablesAccountActions() {
        let account = makeCapabilitiesAccount()
        let capabilities = makeAccountStoreCapabilities(
            accounts: [account],
            settings: quotaEnabledSettings(),
            currentAuthMetadata: makeCapabilitiesMetadata(),
            isLoginInProgress: true
        )

        XCTAssertFalse(capabilities.canLoginNewAccount)
        XCTAssertFalse(capabilities.canImportAccount)
        XCTAssertFalse(capabilities.canRefreshAccounts)
        XCTAssertFalse(capabilities.canRefreshQuotas)
        XCTAssertFalse(capabilities.canSwitch(to: account))
        XCTAssertFalse(capabilities.canRemove(account))
        XCTAssertFalse(capabilities.canBeginRename(account))
        XCTAssertFalse(capabilities.canRename(account, to: "renamed"))
        XCTAssertTrue(capabilities.isStatusBusy)
    }

    func testCurrentAuthSaveRequiresUnreadSavedAuthAndIdleAccountWork() {
        let metadata = makeCapabilitiesMetadata()

        XCTAssertTrue(makeAccountStoreCapabilities(currentAuthMetadata: metadata).canSaveCurrentAuth)
        XCTAssertTrue(makeAccountStoreCapabilities(currentAuthMetadata: metadata).canAddCurrentLogin)
        XCTAssertFalse(makeAccountStoreCapabilities().canSaveCurrentAuth)
        XCTAssertFalse(makeAccountStoreCapabilities(
            currentAuthMetadata: metadata,
            savedAccountForCurrentAuth: makeCapabilitiesAccount()
        ).canSaveCurrentAuth)
        XCTAssertFalse(makeAccountStoreCapabilities(
            currentAuthMetadata: metadata,
            isRefreshInProgress: true
        ).canAddCurrentLogin)
    }

    func testQuotaRefreshRequiresNetworkAccountsAndIdleAccountWork() {
        let account = makeCapabilitiesAccount()

        XCTAssertTrue(makeAccountStoreCapabilities(
            accounts: [account],
            settings: quotaEnabledSettings()
        ).canRefreshQuotas)
        XCTAssertFalse(makeAccountStoreCapabilities(
            accounts: [],
            settings: quotaEnabledSettings()
        ).canRefreshQuotas)
        XCTAssertFalse(makeAccountStoreCapabilities(
            accounts: [account],
            settings: AppSettings(allowNetworkQuotaAPIs: false)
        ).canRefreshQuotas)
        XCTAssertFalse(makeAccountStoreCapabilities(
            accounts: [account],
            settings: quotaEnabledSettings(),
            isQuotaRefreshInProgress: true
        ).canRefreshQuotas)
    }
}
