import Foundation
@testable import CodexKeyringDomain

func makeStatusMessageAccount(id: UUID, authMode: String = "chatgpt") -> CodexAccount {
    CodexAccount(
        id: id,
        alias: "person",
        email: "person@example.com",
        plan: "plus",
        authMode: authMode,
        accountIdentifier: "acct",
        snapshotFileName: "snapshot.json",
        fingerprint: "fingerprint-\(id.uuidString)",
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0),
        tokenExpiresAt: nil
    )
}
