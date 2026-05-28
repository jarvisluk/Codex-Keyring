import Foundation

struct AddAccountMutationRequest: Sendable {
    let metadata: AuthMetadata
    let manifest: AccountManifest
    let sourceURL: URL
    let requestedAlias: String?
    let cleanedAlias: String
    let initialPreferences: AccountAgentPreferences?
    let agentPreferencesWarningReason: String?
    let now: Date
    let activate: Bool
}
