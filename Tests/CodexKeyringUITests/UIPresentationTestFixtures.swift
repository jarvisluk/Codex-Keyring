import Foundation
@testable import CodexKeyringDomain

func makePresentationAccount(
    alias: String = "Personal",
    email: String = "person@example.com",
    plan: String = "Plus",
    authMode: String = "chatgpt",
    accountIdentifier: String = "acct",
    fingerprint: String = "fingerprint"
) -> CodexAccount {
    CodexAccount(
        id: UUID(),
        alias: alias,
        email: email,
        plan: plan,
        authMode: authMode,
        accountIdentifier: accountIdentifier,
        snapshotFileName: "snapshot.json",
        fingerprint: fingerprint,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0),
        tokenExpiresAt: nil
    )
}

func makePresentationMetadata(
    email: String,
    plan: String = "Plus",
    authMode: String = "chatgpt",
    fingerprint: String = "fingerprint"
) -> AuthMetadata {
    AuthMetadata(
        email: email,
        plan: plan,
        authMode: authMode,
        accountIdentifier: "acct",
        fingerprint: fingerprint,
        tokenExpiresAt: nil
    )
}
