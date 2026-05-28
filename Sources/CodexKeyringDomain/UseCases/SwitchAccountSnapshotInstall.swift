import Foundation

struct SwitchAccountInstalledSnapshot: Sendable {
    let restoreURL: URL?
    let didInstall: Bool

    static let skipped = SwitchAccountInstalledSnapshot(
        restoreURL: nil,
        didInstall: false
    )
}

extension SwitchAccountUseCase {
    func installSnapshotIfNeeded(
        snapshotURL: URL,
        wasAlreadyActive: Bool
    ) async throws -> SwitchAccountInstalledSnapshot {
        guard !wasAlreadyActive else {
            return .skipped
        }

        let restoreURL = try await backupCurrentForSwitch()
        try await installer.install(snapshot: snapshotURL)
        return SwitchAccountInstalledSnapshot(
            restoreURL: restoreURL,
            didInstall: true
        )
    }

    func saveManifestAfterInstall(
        _ manifest: AccountManifest,
        installedSnapshot: SwitchAccountInstalledSnapshot
    ) async throws {
        do {
            try await repository.save(manifest)
        } catch {
            if installedSnapshot.didInstall {
                try await restorePreviousLiveAuth(
                    from: installedSnapshot.restoreURL,
                    after: error
                )
            }
            throw error
        }
    }

    private func backupCurrentForSwitch() async throws -> URL? {
        do {
            return try await installer.backupCurrent()
        } catch let error as CodexKeyringError {
            if case .backupFailed = error {
                throw error
            }
            throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
        } catch {
            throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
        }
    }

    private func restorePreviousLiveAuth(from restoreURL: URL?, after originalError: Error) async throws {
        do {
            try await installer.restoreLiveAuth(from: restoreURL)
        } catch {
            let reason = "Manifest save failed after installing the selected account: "
                + "\(originalError.localizedDescription). Previous auth restore failed: "
                + error.localizedDescription
            throw CodexKeyringError.previousAuthRestoreFailed(
                reason: reason,
                recoveryPath: restoreURL?.path
            )
        }
    }
}
