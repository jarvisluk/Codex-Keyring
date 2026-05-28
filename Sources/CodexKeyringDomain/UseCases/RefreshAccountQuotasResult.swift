import Foundation

public struct RefreshAccountQuotasResult: Sendable {
    public var states: [UUID: AccountQuotaState]
    public var accounts: [CodexAccount]

    public init(states: [UUID: AccountQuotaState], accounts: [CodexAccount]) {
        self.states = states
        self.accounts = accounts
    }
}
