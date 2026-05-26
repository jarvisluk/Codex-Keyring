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
        tokenExpiresAt: Date?
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
    }

    public var shortFingerprint: String {
        String(fingerprint.prefix(10))
    }

    public var displayName: String {
        alias.isEmpty ? email : alias
    }

    public var displayEmail: String {
        email.isEmpty ? "Unknown email" : email
    }
}

public struct AuthMetadata: Hashable, Sendable {
    public var email: String
    public var plan: String
    public var authMode: String
    public var accountIdentifier: String
    public var fingerprint: String
    public var tokenExpiresAt: Date?

    public init(
        email: String,
        plan: String,
        authMode: String,
        accountIdentifier: String,
        fingerprint: String,
        tokenExpiresAt: Date?
    ) {
        self.email = email
        self.plan = plan
        self.authMode = authMode
        self.accountIdentifier = accountIdentifier
        self.fingerprint = fingerprint
        self.tokenExpiresAt = tokenExpiresAt
    }
}
