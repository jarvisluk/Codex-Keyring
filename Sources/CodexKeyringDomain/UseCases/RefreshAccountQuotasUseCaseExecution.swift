import Foundation

extension RefreshAccountQuotasUseCase {
    public func callAsFunction() async throws -> RefreshAccountQuotasResult {
        var manifest = try await repository.load()
        guard manifest.settings.allowNetworkQuotaAPIs else {
            return RefreshAccountQuotasResult(states: [:], accounts: manifest.accounts)
        }

        var states: [UUID: AccountQuotaState] = [:]
        var didUpdateManifest = false

        for account in manifest.accounts {
            let result = await refreshQuota(for: account, in: manifest)
            states[account.id] = result.state
            if let metadata = result.updatedMetadata {
                didUpdateManifest = apply(metadata, toAccountID: account.id, in: &manifest) || didUpdateManifest
            }
        }

        if didUpdateManifest {
            try await repository.save(manifest)
        }

        return RefreshAccountQuotasResult(states: states, accounts: manifest.accounts)
    }
}
