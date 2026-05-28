import Foundation

public struct CodexAccount: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var alias: String
    public var email: String
    public var plan: String
    public var authMode: String
    public var accountIdentifier: String
    public var snapshotFileName: String
    public var fingerprint: String
    public var createdAt: Date
    public var updatedAt: Date
    public var tokenExpiresAt: Date?
    /// Per-account Codex agent preferences (model / effort / approval / sandbox
    /// / agent-mode / skip-confirm). Optional so existing accounts decoded from
    /// older manifests still parse.
    public var agentPreferences: AccountAgentPreferences?

    public init(
        id: UUID,
        alias: String,
        email: String,
        plan: String,
        authMode: String,
        accountIdentifier: String,
        snapshotFileName: String,
        fingerprint: String,
        createdAt: Date,
        updatedAt: Date,
        tokenExpiresAt: Date?,
        agentPreferences: AccountAgentPreferences? = nil
    ) {
        self.id = id
        self.alias = alias
        self.email = email
        self.plan = plan
        self.authMode = authMode
        self.accountIdentifier = accountIdentifier
        self.snapshotFileName = snapshotFileName
        self.fingerprint = fingerprint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tokenExpiresAt = tokenExpiresAt
        self.agentPreferences = agentPreferences
    }

    public var shortFingerprint: String {
        String(fingerprint.prefix(10))
    }

    public var displayName: String {
        let cleanedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedAlias.isEmpty ? displayEmail : cleanedAlias
    }

    public var displayEmail: String {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedEmail.isEmpty ? "Unknown email" : cleanedEmail
    }

    public static func displayOrderPrecedes(_ lhs: CodexAccount, _ rhs: CodexAccount) -> Bool {
        let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }

        let emailOrder = lhs.displayEmail.localizedCaseInsensitiveCompare(rhs.displayEmail)
        if emailOrder != .orderedSame {
            return emailOrder == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
