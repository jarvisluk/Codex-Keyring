import Foundation
@testable import CodexKeyringDomain

struct SwitchPreferenceScenario {
    let oldAccount: CodexAccount
    let newAccount: CodexAccount
    let liveURL: URL
    let registry: AuthFileRegistry
    let repository: InMemoryAccountRepository
    let installer: MockInstaller
}

func makeSwitchPreferenceScenario(
    settings: AppSettings = AppSettings(
        restartCodexAppAfterSwitch: true,
        launchAtLogin: false,
        allowNetworkQuotaAPIs: false,
        preserveAgentPreferencesPerAccount: true
    ),
    incomingPreferences: AccountAgentPreferences? = AccountAgentPreferences(model: "gpt-5.5")
) -> SwitchPreferenceScenario {
    let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
    let newMeta = metadata(email: "new@example.com", fingerprint: "new")
    let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
    var newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
    newAccount.agentPreferences = incomingPreferences
    let liveURL = testAuthURL("live-auth.json")
    let registry = AuthFileRegistry([liveURL: oldMeta])
    let repository = accountRepository(
        accounts: [oldAccount, newAccount],
        activeAccountID: oldAccount.id,
        settings: settings
    )
    registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
    let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

    return SwitchPreferenceScenario(
        oldAccount: oldAccount,
        newAccount: newAccount,
        liveURL: liveURL,
        registry: registry,
        repository: repository,
        installer: installer
    )
}
