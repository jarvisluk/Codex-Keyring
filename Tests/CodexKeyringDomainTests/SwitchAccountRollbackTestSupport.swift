import Foundation
@testable import CodexKeyringDomain

struct SwitchRollbackScenario {
    let oldAccount: CodexAccount?
    let newAccount: CodexAccount
    let liveURL: URL
    let registry: AuthFileRegistry
    let repository: InMemoryAccountRepository
    let installer: MockInstaller
    let saveError: CodexKeyringError

    func useCase() -> SwitchAccountUseCase {
        switchAccountUseCase(
            repository: repository,
            installer: installer,
            registry: registry,
            appController: MockAppController(outcome: .relaunched)
        )
    }
}

func makeSwitchRollbackScenario(
    hasPreviousAuth: Bool = true,
    restoreError: Error? = nil
) -> SwitchRollbackScenario {
    let old = metadata(email: "old@example.com", fingerprint: "old")
    let new = metadata(email: "new@example.com", fingerprint: "new")
    let oldAccount = hasPreviousAuth ? account(id: UUID(), alias: "old", metadata: old) : nil
    let newAccount = account(id: UUID(), alias: "new", metadata: new)
    let liveURL = testAuthURL("live-auth.json")
    let registry = AuthFileRegistry(hasPreviousAuth ? [liveURL: old] : [:])
    let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
    let repository = accountRepository(
        accounts: [oldAccount, newAccount].compactMap { $0 },
        activeAccountID: oldAccount?.id,
        saveError: saveError
    )
    registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
    let installer = MockInstaller(
        liveAuthFileURL: liveURL,
        registry: registry,
        restoreError: restoreError
    )

    return SwitchRollbackScenario(
        oldAccount: oldAccount,
        newAccount: newAccount,
        liveURL: liveURL,
        registry: registry,
        repository: repository,
        installer: installer,
        saveError: saveError
    )
}
