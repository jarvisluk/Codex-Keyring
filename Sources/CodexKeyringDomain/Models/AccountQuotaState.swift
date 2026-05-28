import Foundation

public struct AccountQuotaState: Equatable, Sendable {
    public var accountID: UUID
    public var phase: AccountQuotaPhase
    public var snapshot: AccountQuotaSnapshot?
    public var message: String?
    public var updatedAt: Date?

    public init(
        accountID: UUID,
        phase: AccountQuotaPhase,
        snapshot: AccountQuotaSnapshot? = nil,
        message: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.accountID = accountID
        self.phase = phase
        self.snapshot = snapshot
        self.message = message
        self.updatedAt = updatedAt
    }

    public var health: QuotaHealth {
        if let snapshot { return snapshot.health }
        switch phase {
        case .unsupported:
            return .unsupported
        case .error:
            return .error
        case .available:
            return .ready
        case .idle, .loading:
            return .unsupported
        }
    }

    public static func loading(accountID: UUID) -> AccountQuotaState {
        AccountQuotaState(accountID: accountID, phase: .loading)
    }

    public static func unsupported(
        accountID: UUID,
        message: String,
        updatedAt: Date
    ) -> AccountQuotaState {
        AccountQuotaState(
            accountID: accountID,
            phase: .unsupported,
            message: message,
            updatedAt: updatedAt
        )
    }

    public static func error(
        accountID: UUID,
        message: String,
        updatedAt: Date
    ) -> AccountQuotaState {
        AccountQuotaState(
            accountID: accountID,
            phase: .error,
            message: message,
            updatedAt: updatedAt
        )
    }

    public static func available(_ snapshot: AccountQuotaSnapshot) -> AccountQuotaState {
        AccountQuotaState(
            accountID: snapshot.accountID,
            phase: .available,
            snapshot: snapshot,
            updatedAt: snapshot.fetchedAt
        )
    }
}
