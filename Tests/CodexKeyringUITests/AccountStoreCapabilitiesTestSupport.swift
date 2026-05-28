import CodexKeyringDomain
@testable import CodexKeyringUI

func makeAccountStoreCapabilities(
    accounts: [CodexAccount] = [],
    settings: AppSettings = AppSettings(),
    currentAuthMetadata: AuthMetadata? = nil,
    savedAccountForCurrentAuth: CodexAccount? = nil,
    isLaunchAtLoginSupported: Bool = false,
    isLoggingAvailable: Bool = false,
    isRefreshInProgress: Bool = false,
    isLoginInProgress: Bool = false,
    isQuotaRefreshInProgress: Bool = false,
    isLogExportInProgress: Bool = false,
    isOperationInProgress: Bool = false
) -> AccountStoreCapabilities {
    AccountStoreCapabilities(
        accounts: accounts,
        settings: settings,
        currentAuthMetadata: currentAuthMetadata,
        savedAccountForCurrentAuth: savedAccountForCurrentAuth,
        isLaunchAtLoginSupported: isLaunchAtLoginSupported,
        isLoggingAvailable: isLoggingAvailable,
        isRefreshInProgress: isRefreshInProgress,
        isLoginInProgress: isLoginInProgress,
        isQuotaRefreshInProgress: isQuotaRefreshInProgress,
        isLogExportInProgress: isLogExportInProgress,
        isOperationInProgress: isOperationInProgress
    )
}

func makeCapabilitiesAccount() -> CodexAccount {
    makePresentationAccount(alias: "person", plan: "plus")
}

func makeCapabilitiesMetadata() -> AuthMetadata {
    makePresentationMetadata(email: "person@example.com", plan: "plus")
}
