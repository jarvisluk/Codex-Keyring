import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountQuotaStateReducerTests: XCTestCase {
    func testPruningRemovesStatesForMissingAccounts() {
        let kept = makeAccount(alias: "kept")
        let removedID = UUID()
        let states: [UUID: AccountQuotaState] = [
            kept.id: .unsupported(
                accountID: kept.id,
                message: "unsupported",
                updatedAt: Date(timeIntervalSince1970: 1)
            ),
            removedID: .loading(accountID: removedID)
        ]

        let pruned = AccountQuotaStateReducer.pruning(states, keepingAccounts: [kept])

        XCTAssertEqual(Set(pruned.keys), [kept.id])
    }

    func testMarkingChatGPTAccountsLoadingLeavesAPIKeyAccountsUntouched() {
        let chatGPT = makeAccount(alias: "chatgpt", authMode: "chatgpt")
        let apiKey = makeAccount(alias: "api", authMode: "api-key")
        let apiState = AccountQuotaState.unsupported(
            accountID: apiKey.id,
            message: "unsupported",
            updatedAt: Date(timeIntervalSince1970: 1)
        )

        let states = AccountQuotaStateReducer.markingChatGPTAccountsLoading(
            [apiKey.id: apiState],
            accounts: [chatGPT, apiKey]
        )

        XCTAssertEqual(states[chatGPT.id]?.phase, .loading)
        XCTAssertEqual(states[apiKey.id]?.phase, .unsupported)
    }

    func testMarkingLoadingStatesFailedPreservesFinishedStates() {
        let loadingID = UUID()
        let unsupportedID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 42)
        let states: [UUID: AccountQuotaState] = [
            loadingID: .loading(accountID: loadingID),
            unsupportedID: .unsupported(
                accountID: unsupportedID,
                message: "unsupported",
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        ]

        let updated = AccountQuotaStateReducer.markingLoadingStatesFailed(
            states,
            message: "disk full",
            updatedAt: updatedAt
        )

        XCTAssertEqual(updated[loadingID]?.phase, .error)
        XCTAssertEqual(updated[loadingID]?.message, "disk full")
        XCTAssertEqual(updated[loadingID]?.updatedAt, updatedAt)
        XCTAssertEqual(updated[unsupportedID]?.phase, .unsupported)
    }

    private func makeAccount(alias: String, authMode: String = "chatgpt") -> CodexAccount {
        CodexAccount(
            id: UUID(),
            alias: alias,
            email: "\(alias)@example.com",
            plan: "plus",
            authMode: authMode,
            accountIdentifier: "acct-\(alias)",
            snapshotFileName: "\(alias).json",
            fingerprint: "fingerprint-\(alias)",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            tokenExpiresAt: nil
        )
    }
}
