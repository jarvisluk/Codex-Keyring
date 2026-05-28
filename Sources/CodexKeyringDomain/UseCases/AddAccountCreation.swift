import Foundation

extension AddAccountUseCase {
    func createAccount(
        request: AddAccountMutationRequest
    ) async throws -> AddAccountResult {
        var manifest = request.manifest
        let id = UUID()
        let uniqueAlias = aliasPolicy.uniquified(
            request.cleanedAlias,
            among: manifest.accounts
        )
        let snapshotName = try await repository.writeSnapshot(from: request.sourceURL, for: id)
        let account = CodexAccount(
            id: id,
            alias: uniqueAlias,
            email: request.metadata.email,
            plan: request.metadata.plan,
            authMode: request.metadata.authMode,
            accountIdentifier: request.metadata.accountIdentifier,
            snapshotFileName: snapshotName,
            fingerprint: request.metadata.fingerprint,
            createdAt: request.now,
            updatedAt: request.now,
            tokenExpiresAt: request.metadata.tokenExpiresAt,
            agentPreferences: request.initialPreferences
        )

        manifest.accounts.append(account)
        manifest.accounts = sorted(manifest.accounts)
        if request.activate {
            manifest.activeAccountID = account.id
        }

        do {
            try await repository.save(manifest)
        } catch {
            try await cleanupSnapshot(named: snapshotName, after: error)
            throw error
        }

        return try await result(
            manifest: manifest,
            savedAlias: account.alias,
            wasUpdate: false,
            agentPreferencesWarningReason: request.agentPreferencesWarningReason
        )
    }
}
