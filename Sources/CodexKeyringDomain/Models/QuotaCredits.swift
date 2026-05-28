import Foundation

public struct QuotaCredits: Codable, Equatable, Sendable {
    public var balance: String?
    public var hasCredits: Bool
    public var unlimited: Bool

    public init(balance: String?, hasCredits: Bool, unlimited: Bool) {
        self.balance = balance
        self.hasCredits = hasCredits
        self.unlimited = unlimited
    }

    public var isDepleted: Bool {
        guard hasCredits, !unlimited else { return false }
        guard let balance = balance?.trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Double(balance)
        else {
            return false
        }
        return value <= 0
    }
}
