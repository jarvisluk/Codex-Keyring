import Foundation

public struct RefreshAccountQuotasResult: Sendable {
    public var states: [UUID: AccountQuotaState]
    public var accounts: [CodexAccount]

    public init(states: [UUID: AccountQuotaState], accounts: [CodexAccount]) {
        self.states = states
        self.accounts = accounts
    }
}

public struct RefreshAccountQuotasUseCase: Sendable {
    private let repository: AccountRepository
    private let installer: CodexAuthInstalling
    private let query: AccountQuotaQuerying
    private let clock: Clock

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        query: AccountQuotaQuerying,
        clock: Clock = SystemClock()
    ) {
        self.repository = repository
        self.installer = installer
        self.query = query
        self.clock = clock
    }

    public func callAsFunction() async throws -> RefreshAccountQuotasResult {
        var manifest = try await repository.load()
        guard manifest.settings.allowNetworkQuotaAPIs else {
            return RefreshAccountQuotasResult(states: [:], accounts: manifest.accounts)
        }

        var states: [UUID: AccountQuotaState] = [:]
        var didUpdateManifest = false

        for account in manifest.accounts {
            let now = clock.now()
            guard account.authMode == "chatgpt" else {
                states[account.id] = .unsupported(
                    accountID: account.id,
                    message: "Only ChatGPT/Codex OAuth accounts expose quota.",
                    updatedAt: now
                )
                continue
            }

            guard repository.snapshotExists(named: account.snapshotFileName) else {
                states[account.id] = .error(
                    accountID: account.id,
                    message: "The saved auth snapshot is missing.",
                    updatedAt: now
                )
                continue
            }

            let liveAuthFileURL = manifest.activeAccountID == account.id
                ? installer.liveAuthFileURL
                : nil
            let request = AccountQuotaQueryRequest(
                account: account,
                snapshotURL: repository.snapshotURL(named: account.snapshotFileName),
                liveAuthFileURL: liveAuthFileURL
            )

            do {
                let result = try await query.queryQuota(for: request)
                states[account.id] = result.state
                if let metadata = result.updatedMetadata,
                   let index = manifest.accounts.firstIndex(where: { $0.id == account.id })
                {
                    manifest.accounts[index].email = metadata.email
                    manifest.accounts[index].plan = metadata.plan
                    manifest.accounts[index].authMode = metadata.authMode
                    manifest.accounts[index].accountIdentifier = metadata.accountIdentifier
                    manifest.accounts[index].fingerprint = metadata.fingerprint
                    manifest.accounts[index].tokenExpiresAt = metadata.tokenExpiresAt
                    manifest.accounts[index].updatedAt = clock.now()
                    didUpdateManifest = true
                }
            } catch {
                states[account.id] = .error(
                    accountID: account.id,
                    message: error.localizedDescription,
                    updatedAt: clock.now()
                )
            }
        }

        if didUpdateManifest {
            try await repository.save(manifest)
        }

        return RefreshAccountQuotasResult(states: states, accounts: manifest.accounts)
    }
}
