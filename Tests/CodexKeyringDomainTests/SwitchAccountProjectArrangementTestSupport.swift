import Foundation
@testable import CodexKeyringDomain

struct SwitchProjectArrangementScenario {
    let newAccount: CodexAccount
    let registry: AuthFileRegistry
    let repository: InMemoryAccountRepository
    let installer: MockInstaller
    let appController: MockAppController
    let port: MockAgentPreferencesPort
    let arrangement: CodexProjectArrangement

    func useCase() -> SwitchAccountUseCase {
        switchAccountUseCase(
            repository: repository,
            installer: installer,
            registry: registry,
            appController: appController,
            preferencesPort: port
        )
    }
}

func makeSwitchProjectArrangementScenario(
    arrangement: CodexProjectArrangement = CodexProjectArrangement(),
    projectArrangementCaptureError: Error? = nil,
    projectArrangementRestoreError: Error? = nil
) -> SwitchProjectArrangementScenario {
    let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
    let newMeta = metadata(email: "new@example.com", fingerprint: "new")
    let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
    let newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
    let liveURL = testAuthURL("live-auth.json")
    let registry = AuthFileRegistry([liveURL: oldMeta])
    let settings = AppSettings(preserveAgentPreferencesPerAccount: false)
    let repository = accountRepository(
        accounts: [oldAccount, newAccount],
        activeAccountID: oldAccount.id,
        settings: settings
    )
    registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
    let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
    let appController = MockAppController(outcome: .relaunched)
    let port = MockAgentPreferencesPort(
        projectArrangement: arrangement,
        projectArrangementCaptureError: projectArrangementCaptureError,
        projectArrangementRestoreError: projectArrangementRestoreError
    )

    return SwitchProjectArrangementScenario(
        newAccount: newAccount,
        registry: registry,
        repository: repository,
        installer: installer,
        appController: appController,
        port: port,
        arrangement: arrangement
    )
}
