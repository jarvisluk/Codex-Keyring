import Foundation

public struct AccountQuotaQueryRequest: Sendable {
    public var account: CodexAccount
    public var snapshotURL: URL
    public var liveAuthFileURL: URL?

    public init(account: CodexAccount, snapshotURL: URL, liveAuthFileURL: URL?) {
        self.account = account
        self.snapshotURL = snapshotURL
        self.liveAuthFileURL = liveAuthFileURL
    }
}

public struct AccountQuotaQueryResult: Sendable {
    public var state: AccountQuotaState
    public var updatedMetadata: AuthMetadata?

    public init(state: AccountQuotaState, updatedMetadata: AuthMetadata? = nil) {
        self.state = state
        self.updatedMetadata = updatedMetadata
    }
}

public protocol AccountQuotaQuerying: Sendable {
    func queryQuota(for request: AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult
}

public struct NoopAccountQuotaQuery: AccountQuotaQuerying {
    public init() {}

    public func queryQuota(for request: AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult {
        AccountQuotaQueryResult(
            state: .unsupported(
                accountID: request.account.id,
                message: "Quota querying is not configured.",
                updatedAt: Date()
            )
        )
    }
}
