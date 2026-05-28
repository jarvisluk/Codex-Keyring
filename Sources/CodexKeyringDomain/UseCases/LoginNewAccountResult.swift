import Foundation

public struct LoginNewAccountResult: Sendable {
    public let state: AccountState
    public let savedAlias: String
    public let cleanupWarningReason: String?
}
