import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class AccountStoreMutationStatusMessagesTests: XCTestCase {
    func testRemoveAccountReportsNoopAndRemovedAccount() {
        XCTAssertEqual(
            AccountStoreStatusMessages.removeAccount(
                result: RemoveAccountResult(state: .empty, removedAlias: "")
            ),
            "Account was already removed."
        )
        XCTAssertEqual(
            AccountStoreStatusMessages.removeAccount(
                result: RemoveAccountResult(state: .empty, removedAlias: "Work")
            ),
            "Removed saved account Work. Current Codex auth was left untouched."
        )
    }

    func testRenameAccountUsesUpdatedDisplayName() {
        let id = UUID()
        var account = makeStatusMessageAccount(id: id)
        account.alias = ""
        let result = RenameAccountResult(
            state: AccountState(accounts: [account]),
            newAlias: "",
            didRename: true
        )

        XCTAssertEqual(
            AccountStoreStatusMessages.renameAccount(result: result, accountID: id),
            "Cleared alias. Account will show as person@example.com."
        )
    }
}
