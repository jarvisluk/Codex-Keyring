import Foundation

extension AddAccountUseCase {
    func sorted(_ accounts: [CodexAccount]) -> [CodexAccount] {
        accounts.sorted(by: CodexAccount.displayOrderPrecedes)
    }

    func result(
        manifest: AccountManifest,
        savedAlias: String,
        wasUpdate: Bool,
        agentPreferencesWarningReason: String?
    ) async throws -> AddAccountResult {
        let currentAuth = try? await authReader.readIfPresent(from: installer.liveAuthFileURL)
        return AddAccountResult(
            state: AccountState(manifest: manifest, currentAuthMetadata: currentAuth),
            savedAlias: savedAlias,
            wasUpdate: wasUpdate,
            agentPreferencesWarningReason: agentPreferencesWarningReason
        )
    }

    func rollbackManifest(to originalManifest: AccountManifest, after originalError: Error) async throws {
        do {
            try await repository.save(originalManifest)
        } catch {
            throw CodexKeyringError.manifestRollbackFailed(
                originalReason: originalError.localizedDescription,
                rollbackReason: error.localizedDescription
            )
        }
    }

    func cleanupSnapshot(named snapshotName: String, after originalError: Error) async throws {
        do {
            try await repository.deleteSnapshot(named: snapshotName)
        } catch {
            throw CodexKeyringError.snapshotCleanupFailed(
                originalReason: originalError.localizedDescription,
                cleanupReason: error.localizedDescription,
                snapshotFileName: snapshotName
            )
        }
    }
}
