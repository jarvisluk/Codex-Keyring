import Foundation

extension SwitchAccountUseCase {
    func readLiveAuthIfPresent() async throws -> AuthMetadata? {
        try await authReader.readIfPresent(from: installer.liveAuthFileURL)
    }

    func readSelectedSnapshot(from url: URL, accountID: UUID) async throws -> AuthMetadata {
        do {
            return try await authReader.read(from: url)
        } catch CodexKeyringError.authFileMissing {
            throw CodexKeyringError.snapshotMissing(accountID: accountID)
        }
    }

    func syncCurrentLiveAuthIfPresent(
        _ currentAuth: AuthMetadata?,
        manifest: inout AccountManifest
    ) async throws {
        // Preserve the latest live auth before replacing ~/.codex/auth.json.
        guard let currentAuth else { return }
        do {
            _ = try await syncLiveAuth.sync(
                liveMetadata: currentAuth,
                liveURL: installer.liveAuthFileURL,
                manifest: &manifest
            )
        } catch {
            throw CodexKeyringError.currentAuthSyncFailed(reason: error.localizedDescription)
        }
    }

    func isAlreadyActive(
        account: CodexAccount,
        currentAuth: AuthMetadata?,
        manifest: AccountManifest
    ) -> Bool {
        guard let live = currentAuth else { return false }
        return manifest.accounts.first(where: { $0.id == account.id })?.fingerprint == live.fingerprint
    }
}
