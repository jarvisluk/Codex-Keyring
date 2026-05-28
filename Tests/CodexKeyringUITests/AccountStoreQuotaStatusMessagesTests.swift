import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountStoreQuotaStatusMessagesTests: XCTestCase {
    func testQuotaRefreshExplainsMixedSuccessAndErrors() {
        let availableID = UUID()
        let errorID = UUID()
        let result = RefreshAccountQuotasResult(
            states: [
                availableID: .available(makeQuotaSnapshot(accountID: availableID)),
                errorID: .error(
                    accountID: errorID,
                    message: "disk full",
                    updatedAt: Date(timeIntervalSince1970: 1)
                )
            ],
            accounts: [
                makeStatusMessageAccount(id: availableID),
                makeStatusMessageAccount(id: errorID)
            ]
        )

        XCTAssertEqual(
            AccountStoreStatusMessages.quotaRefresh(result: result),
            "Refreshed quota for 1 account. 1 account need attention."
        )
    }
}
