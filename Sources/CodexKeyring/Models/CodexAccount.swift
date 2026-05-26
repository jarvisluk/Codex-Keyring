import Foundation

struct CodexAccount: Identifiable, Codable, Hashable {
    var id: UUID
    var alias: String
    var email: String
    var plan: String
    var authMode: String
    var accountIdentifier: String
    var snapshotFileName: String
    var fingerprint: String
    var createdAt: Date
    var updatedAt: Date
    var tokenExpiresAt: Date?

    var shortFingerprint: String {
        String(fingerprint.prefix(10))
    }

    var displayName: String {
        alias.isEmpty ? email : alias
    }

    var displayEmail: String {
        email.isEmpty ? "Unknown email" : email
    }
}

struct AuthMetadata: Hashable {
    var email: String
    var plan: String
    var authMode: String
    var accountIdentifier: String
    var fingerprint: String
    var tokenExpiresAt: Date?
}
