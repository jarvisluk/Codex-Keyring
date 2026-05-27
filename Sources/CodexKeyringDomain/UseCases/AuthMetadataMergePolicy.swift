import Foundation

/// Merges freshly parsed auth metadata into a saved account without replacing
/// useful manifest values with parser fallbacks from sparse tokens.
struct AuthMetadataMergePolicy: Sendable {
    func merged(_ metadata: AuthMetadata, into account: CodexAccount) -> CodexAccount {
        var updated = account
        updated.email = merge(
            current: updated.email,
            candidate: metadata.email,
            ignoredCandidates: ["unknown account"]
        )
        updated.plan = merge(
            current: updated.plan,
            candidate: metadata.plan,
            ignoredCandidates: ["chatgpt"]
        )
        updated.authMode = merge(current: updated.authMode, candidate: metadata.authMode)
        updated.accountIdentifier = merge(current: updated.accountIdentifier, candidate: metadata.accountIdentifier)
        updated.fingerprint = merge(current: updated.fingerprint, candidate: metadata.fingerprint)
        updated.tokenExpiresAt = metadata.tokenExpiresAt ?? updated.tokenExpiresAt
        return updated
    }

    private func merge(
        current: String,
        candidate: String,
        ignoredCandidates: Set<String> = []
    ) -> String {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !ignoredCandidates.contains(trimmed.lowercased())
        else {
            return current
        }
        return trimmed
    }
}
