import Foundation

extension RefreshAccountQuotasUseCase {
    func apply(
        _ metadata: AuthMetadata,
        toAccountID accountID: UUID,
        in manifest: inout AccountManifest
    ) -> Bool {
        guard let index = manifest.accounts.firstIndex(where: { $0.id == accountID }) else {
            return false
        }

        let original = manifest.accounts[index]
        var updated = AuthMetadataMergePolicy().merged(metadata, into: original)
        guard updated != original else { return false }
        updated.updatedAt = clock.now()
        manifest.accounts[index] = updated
        return true
    }
}
