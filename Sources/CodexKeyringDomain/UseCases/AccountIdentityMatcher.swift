import Foundation

public enum AccountIdentityMatcher {
    /// Locate the saved account that a live auth file most likely belongs to.
    /// Preference order:
    ///   1. Exact fingerprint match (no token rotation has happened).
    ///   2. Same stable OAuth `accountIdentifier`.
    ///
    /// Parser placeholder identifiers are shared across multiple accounts, so
    /// they are not safe to treat as unique identities.
    public static func firstMatchingAccount(
        for metadata: AuthMetadata,
        in accounts: [CodexAccount]
    ) -> CodexAccount? {
        guard let index = firstMatchingIndex(for: metadata, in: accounts) else {
            return nil
        }
        return accounts[index]
    }

    public static func firstMatchingIndex(
        for metadata: AuthMetadata,
        in accounts: [CodexAccount]
    ) -> Int? {
        if let exact = accounts.firstIndex(where: { $0.fingerprint == metadata.fingerprint }) {
            return exact
        }

        guard let identifier = stableAccountIdentifier(metadata.accountIdentifier) else {
            return nil
        }
        return accounts.firstIndex { account in
            stableAccountIdentifier(account.accountIdentifier) == identifier
        }
    }

    public static func isStableAccountIdentifier(_ identifier: String) -> Bool {
        stableAccountIdentifier(identifier) != nil
    }

    private static func stableAccountIdentifier(_ identifier: String) -> String? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.localizedCaseInsensitiveCompare(AuthMetadata.apiKeyAccountIdentifier) != .orderedSame,
              trimmed.localizedCaseInsensitiveCompare(AuthMetadata.unknownChatGPTAccountIdentifier) != .orderedSame else {
            return nil
        }
        return trimmed
    }
}
