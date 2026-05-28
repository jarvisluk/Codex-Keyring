import CodexKeyringDomain

struct AccountStoreUseCases {
    let refreshState: RefreshStateUseCase
    let addAccount: AddAccountUseCase
    let switchAccount: SwitchAccountUseCase
    let removeAccount: RemoveAccountUseCase
    let renameAccount: RenameAccountUseCase
    let updateSettings: UpdateSettingsUseCase
    let loginNewAccount: LoginNewAccountUseCase
    let syncLiveAuth: SyncLiveAuthUseCase
    let refreshAccountQuotas: RefreshAccountQuotasUseCase

    init(
        repository: any AccountRepository,
        installer: any CodexAuthInstalling,
        authReader: any AuthFileReading,
        appController: any CodexAppControlling,
        loginService: any CodexLoginServicing,
        agentPreferencesPort: any CodexAgentPreferencesPorting,
        query: any AccountQuotaQuerying
    ) {
        refreshState = RefreshStateUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader
        )
        addAccount = AddAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            preferencesPort: agentPreferencesPort
        )
        switchAccount = SwitchAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            appController: appController,
            preferencesPort: agentPreferencesPort
        )
        removeAccount = RemoveAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader
        )
        renameAccount = RenameAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader
        )
        updateSettings = UpdateSettingsUseCase(repository: repository)
        loginNewAccount = LoginNewAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            loginService: loginService,
            preferencesPort: agentPreferencesPort
        )
        syncLiveAuth = SyncLiveAuthUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader
        )
        refreshAccountQuotas = RefreshAccountQuotasUseCase(
            repository: repository,
            installer: installer,
            query: query
        )
    }
}
