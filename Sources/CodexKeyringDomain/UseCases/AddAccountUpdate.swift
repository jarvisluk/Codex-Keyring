import Foundation

extension AddAccountUseCase {
    func updateExistingAccount(
        at index: Int,
        request: AddAccountMutationRequest
    ) async throws -> AddAccountResult {
        var manifest = request.manifest
        let existing = manifest.accounts[index]
        var updated = updatedAccount(
            existing: existing,
            manifest: manifest,
            request: request
        )

        manifest.accounts[index] = updated
        if request.activate {
            manifest.activeAccountID = updated.id
        }
        manifest.accounts = sorted(manifest.accounts)

        try await repository.save(manifest)
        do {
            _ = try await repository.writeSnapshot(from: request.sourceURL, for: existing.id)
        } catch {
            try await rollbackManifest(to: request.manifest, after: error)
            throw error
        }

        updated = manifest.accounts.first(where: { $0.id == updated.id }) ?? updated
        return try await result(
            manifest: manifest,
            savedAlias: updated.alias,
            wasUpdate: true,
            agentPreferencesWarningReason: request.agentPreferencesWarningReason
        )
    }

    private func updatedAccount(
        existing: CodexAccount,
        manifest: AccountManifest,
        request: AddAccountMutationRequest
    ) -> CodexAccount {
        let requestedUpdateAlias = request.requestedAlias?.trimmingCharacters(in: .whitespacesAndNewlines)
        let updateAlias = if requestedUpdateAlias?.isEmpty == false {
            request.cleanedAlias
        } else {
            existing.alias
        }
        let uniqueAlias = aliasPolicy.uniquified(
            updateAlias,
            among: manifest.accounts,
            excluding: existing.id
        )
        var updated = AuthMetadataMergePolicy().merged(request.metadata, into: existing)
        updated.alias = uniqueAlias
        updated.updatedAt = request.now
        if let initialPreferences = request.initialPreferences {
            updated.agentPreferences = initialPreferences
        }
        return updated
    }
}
