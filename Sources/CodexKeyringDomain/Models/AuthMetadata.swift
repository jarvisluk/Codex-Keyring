import Foundation

public struct AuthMetadata: Hashable, Sendable {
    public static let apiKeyAccountIdentifier = "api-key"
    public static let unknownChatGPTAccountIdentifier = "unknown-chatgpt-account"

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
