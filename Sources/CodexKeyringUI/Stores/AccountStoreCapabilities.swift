import Foundation
import CodexKeyringDomain

struct AccountStoreCapabilities {
    var accounts: [CodexAccount]
    var settings: AppSettings
    var currentAuthMetadata: AuthMetadata?
    var savedAccountForCurrentAuth: CodexAccount?
    var isLaunchAtLoginSupported: Bool
    var isLoggingAvailable: Bool
    var isRefreshInProgress: Bool
    var isLoginInProgress: Bool
    var isQuotaRefreshInProgress: Bool
    var isLogExportInProgress: Bool
    var isOperationInProgress: Bool
}
