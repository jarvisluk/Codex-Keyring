import Foundation
@testable import CodexKeyringDomain

func addAccountUseCase(
    repository: InMemoryAccountRepository,
    registry: AuthFileRegistry,
    liveAuthFileURL: URL = testAuthURL("live-auth.json"),
    preferencesPort: any CodexAgentPreferencesPorting = MockAgentPreferencesPort(),
    clock: any Clock = FixedClock(Date(timeIntervalSince1970: 500))
) -> AddAccountUseCase {
    AddAccountUseCase(
        repository: repository,
        installer: MockInstaller(liveAuthFileURL: liveAuthFileURL, registry: registry),
        authReader: MockAuthReader(registry: registry),
        preferencesPort: preferencesPort,
        clock: clock
    )
}

func refreshAccountQuotasUseCase(
    repository: InMemoryAccountRepository,
    query: MockQuotaQuery,
    liveAuthFileURL: URL = testAuthURL("auth.json"),
    registry: AuthFileRegistry = AuthFileRegistry([:]),
    clock: any Clock = FixedClock(Date(timeIntervalSince1970: 123))
) -> RefreshAccountQuotasUseCase {
    RefreshAccountQuotasUseCase(
        repository: repository,
        installer: MockInstaller(liveAuthFileURL: liveAuthFileURL, registry: registry),
        query: query,
        clock: clock
    )
}

func syncLiveAuthUseCase(
    repository: InMemoryAccountRepository,
    registry: AuthFileRegistry = AuthFileRegistry([:]),
    liveAuthFileURL: URL = testAuthURL("live-auth.json"),
    authReader: (any AuthFileReading)? = nil,
    clock: any Clock = FixedClock(Date(timeIntervalSince1970: 400))
) -> SyncLiveAuthUseCase {
    SyncLiveAuthUseCase(
        repository: repository,
        installer: MockInstaller(liveAuthFileURL: liveAuthFileURL, registry: registry),
        authReader: authReader ?? MockAuthReader(registry: registry),
        clock: clock
    )
}

func renameAccountUseCase(
    repository: InMemoryAccountRepository,
    registry: AuthFileRegistry = AuthFileRegistry([:]),
    liveAuthFileURL: URL = testAuthURL("live-auth.json"),
    authReader: (any AuthFileReading)? = nil,
    clock: any Clock = FixedClock(Date(timeIntervalSince1970: 500))
) -> RenameAccountUseCase {
    RenameAccountUseCase(
        repository: repository,
        installer: MockInstaller(liveAuthFileURL: liveAuthFileURL, registry: registry),
        authReader: authReader ?? MockAuthReader(registry: registry),
        clock: clock
    )
}

func removeAccountUseCase(
    repository: InMemoryAccountRepository,
    registry: AuthFileRegistry = AuthFileRegistry([:]),
    liveAuthFileURL: URL = testAuthURL("live-auth.json"),
    authReader: (any AuthFileReading)? = nil
) -> RemoveAccountUseCase {
    RemoveAccountUseCase(
        repository: repository,
        installer: MockInstaller(liveAuthFileURL: liveAuthFileURL, registry: registry),
        authReader: authReader ?? MockAuthReader(registry: registry)
    )
}

func refreshStateUseCase(
    repository: InMemoryAccountRepository,
    registry: AuthFileRegistry = AuthFileRegistry([:]),
    liveAuthFileURL: URL = testAuthURL("live-auth.json"),
    authReader: (any AuthFileReading)? = nil
) -> RefreshStateUseCase {
    RefreshStateUseCase(
        repository: repository,
        installer: MockInstaller(liveAuthFileURL: liveAuthFileURL, registry: registry),
        authReader: authReader ?? MockAuthReader(registry: registry)
    )
}

func switchAccountUseCase(
    repository: InMemoryAccountRepository,
    installer: MockInstaller,
    registry: AuthFileRegistry,
    authReader: (any AuthFileReading)? = nil,
    appController: any CodexAppControlling = MockAppController(outcome: .relaunched),
    preferencesPort: any CodexAgentPreferencesPorting = MockAgentPreferencesPort(),
    clock: any Clock = FixedClock(Date(timeIntervalSince1970: 500))
) -> SwitchAccountUseCase {
    SwitchAccountUseCase(
        repository: repository,
        installer: installer,
        authReader: authReader ?? MockAuthReader(registry: registry),
        appController: appController,
        preferencesPort: preferencesPort,
        clock: clock
    )
}
