import Foundation
@testable import CodexKeyringDomain

final class RotatedLiveAuthRefreshFixture {
    let stored: AuthMetadata
    let live: AuthMetadata
    let savedAccount: CodexAccount
    let liveURL = testAuthURL("live-auth.json")
    let registry: AuthFileRegistry
    let repository: InMemoryAccountRepository

    init(writeError: Error? = nil) {
        let identifier = "user-A"
        stored = metadata(
            email: "a@example.com",
            fingerprint: "fp-A-v1",
            accountIdentifier: identifier
        )
        live = metadata(
            email: "a@example.com",
            fingerprint: "fp-A-v2",
            accountIdentifier: identifier
        )
        savedAccount = account(id: UUID(), alias: "A", metadata: stored)
        registry = AuthFileRegistry([liveURL: live])
        repository = accountRepository(
            accounts: [savedAccount],
            activeAccountID: savedAccount.id,
            writeError: writeError
        )
    }

    func refresh() async throws -> AccountState {
        try await refreshStateUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL
        )()
    }
}
