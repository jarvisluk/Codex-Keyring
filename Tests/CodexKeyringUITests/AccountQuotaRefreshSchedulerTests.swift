import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountQuotaRefreshSchedulerTests: XCTestCase {
    func testEnablingWithAccountsRequestsImmediateRefresh() {
        let scheduler = AccountQuotaRefreshScheduler()
        let accountID = UUID()

        let shouldRefresh = scheduler.configure(
            settings: AppSettings(allowNetworkQuotaAPIs: true),
            accountIDs: [accountID],
            refresh: {}
        )

        XCTAssertTrue(shouldRefresh)
    }

    func testUnchangedConfigurationDoesNotRequestImmediateRefreshAgain() {
        let scheduler = AccountQuotaRefreshScheduler()
        let accountID = UUID()
        let settings = AppSettings(allowNetworkQuotaAPIs: true)

        _ = scheduler.configure(
            settings: settings,
            accountIDs: [accountID],
            refresh: {}
        )
        let shouldRefresh = scheduler.configure(
            settings: settings,
            accountIDs: [accountID],
            refresh: {}
        )

        XCTAssertFalse(shouldRefresh)
    }

    func testAddingAnAccountRequestsImmediateRefresh() {
        let scheduler = AccountQuotaRefreshScheduler()
        let firstID = UUID()
        let secondID = UUID()
        let settings = AppSettings(allowNetworkQuotaAPIs: true)

        _ = scheduler.configure(
            settings: settings,
            accountIDs: [firstID],
            refresh: {}
        )
        let shouldRefresh = scheduler.configure(
            settings: settings,
            accountIDs: [firstID, secondID],
            refresh: {}
        )

        XCTAssertTrue(shouldRefresh)
    }

    func testRemovingAccountsDoesNotRequestImmediateRefresh() {
        let scheduler = AccountQuotaRefreshScheduler()
        let firstID = UUID()
        let secondID = UUID()
        let settings = AppSettings(allowNetworkQuotaAPIs: true)

        _ = scheduler.configure(
            settings: settings,
            accountIDs: [firstID, secondID],
            refresh: {}
        )
        let shouldRefresh = scheduler.configure(
            settings: settings,
            accountIDs: [firstID],
            refresh: {}
        )

        XCTAssertFalse(shouldRefresh)
    }

    func testDisabledOrEmptyConfigurationsDoNotRequestRefresh() {
        let scheduler = AccountQuotaRefreshScheduler()

        XCTAssertFalse(scheduler.configure(
            settings: AppSettings(allowNetworkQuotaAPIs: false),
            accountIDs: [UUID()],
            refresh: {}
        ))
        XCTAssertFalse(scheduler.configure(
            settings: AppSettings(allowNetworkQuotaAPIs: true),
            accountIDs: [],
            refresh: {}
        ))
    }
}
