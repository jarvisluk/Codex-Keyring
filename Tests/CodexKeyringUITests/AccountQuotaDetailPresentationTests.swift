import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountQuotaDetailPresentationTests: XCTestCase {
    func testAccountQuotaDetailPresentationSelectsDisabledAndEmptyContent() {
        let disabled = AccountQuotaDetailPresentation(
            allowNetworkQuotaAPIs: false,
            quotaState: nil,
            canRefreshQuotas: false
        )
        let empty = AccountQuotaDetailPresentation(
            allowNetworkQuotaAPIs: true,
            quotaState: nil,
            canRefreshQuotas: true
        )

        XCTAssertFalse(disabled.canRefreshQuotas)
        XCTAssertEqual(
            disabled.content,
            .networkDisabled("Network quota API calls are disabled in Settings.")
        )
        XCTAssertTrue(empty.canRefreshQuotas)
        XCTAssertEqual(empty.content, .notRefreshed("Quota has not been refreshed yet."))
    }

    func testAccountQuotaDetailPresentationCarriesQuotaStateContent() {
        let accountID = UUID()
        let state = AccountQuotaState.loading(accountID: accountID)

        let presentation = AccountQuotaDetailPresentation(
            allowNetworkQuotaAPIs: true,
            quotaState: state,
            canRefreshQuotas: false
        )

        XCTAssertFalse(presentation.canRefreshQuotas)
        XCTAssertEqual(presentation.content, .quotaState(state))
    }
}
