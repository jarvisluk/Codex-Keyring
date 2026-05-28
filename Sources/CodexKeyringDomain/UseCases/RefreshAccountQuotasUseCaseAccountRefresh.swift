import Foundation

extension RefreshAccountQuotasUseCase {
    func refreshQuota(
        for account: CodexAccount,
        in manifest: AccountManifest
    ) async -> AccountQuotaQueryResult {
        guard account.authMode == "chatgpt" else {
            return AccountQuotaQueryResult(state: unsupportedState(for: account))
        }

        do {
            return try await query.queryQuota(for: quotaRequest(for: account, in: manifest))
        } catch CodexKeyringError.authFileMissing {
            return AccountQuotaQueryResult(
                state: errorState(for: account, message: "The saved auth snapshot is missing.")
            )
        } catch {
            return AccountQuotaQueryResult(
                state: errorState(for: account, message: error.localizedDescription)
            )
        }
    }

    private func quotaRequest(
        for account: CodexAccount,
        in manifest: AccountManifest
    ) -> AccountQuotaQueryRequest {
        let liveAuthFileURL = manifest.activeAccountID == account.id
            ? installer.liveAuthFileURL
            : nil
        return AccountQuotaQueryRequest(
            account: account,
            snapshotURL: repository.snapshotURL(named: account.snapshotFileName),
            liveAuthFileURL: liveAuthFileURL
        )
    }

    private func unsupportedState(for account: CodexAccount) -> AccountQuotaState {
        .unsupported(
            accountID: account.id,
            message: "Only ChatGPT/Codex OAuth accounts expose quota.",
            updatedAt: clock.now()
        )
    }

    private func errorState(for account: CodexAccount, message: String) -> AccountQuotaState {
        .error(
            accountID: account.id,
            message: message,
            updatedAt: clock.now()
        )
    }
}
