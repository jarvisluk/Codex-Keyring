import Foundation

extension SyncLiveAuthUseCase {
    /// Variant used by call sites that already loaded a manifest and just need
    /// the in-place reconciliation. The manifest is updated and persisted
    /// whenever something changes.
    @discardableResult
    public func sync(
        liveMetadata live: AuthMetadata,
        liveURL: URL,
        manifest: inout AccountManifest
    ) async throws -> SyncLiveAuthResult {
        guard let match = AccountIdentityMatcher.firstMatchingAccount(for: live, in: manifest.accounts) else {
            return .noop
        }

        var didUpdateSnapshot = false
        var didUpdateMetadata = false
        let shouldRewriteSnapshot = match.fingerprint != live.fingerprint
        if shouldRewriteSnapshot {
            _ = try await repository.writeSnapshot(from: liveURL, for: match.id)
            didUpdateSnapshot = true
        }

        if let index = manifest.accounts.firstIndex(where: { $0.id == match.id }) {
            let original = manifest.accounts[index]
            var updated = AuthMetadataMergePolicy().merged(live, into: original)
            if updated != original {
                updated.updatedAt = clock.now()
                manifest.accounts[index] = updated
                didUpdateMetadata = true
            }
        }

        var didReassignActive = false
        if manifest.activeAccountID != match.id {
            manifest.activeAccountID = match.id
            didReassignActive = true
        }

        if didUpdateSnapshot || didUpdateMetadata || didReassignActive {
            try await repository.save(manifest)
        }

        return SyncLiveAuthResult(
            updatedAccountID: match.id,
            didUpdateSnapshot: didUpdateSnapshot,
            didUpdateMetadata: didUpdateMetadata,
            didReassignActive: didReassignActive
        )
    }
}
