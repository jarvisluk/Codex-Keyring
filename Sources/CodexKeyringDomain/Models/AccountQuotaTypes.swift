import Foundation

public enum QuotaHealth: String, Codable, Equatable, Sendable {
    case ready
    case watch
    case low
    case blocked
    case error
    case unsupported
}

public enum AccountQuotaPhase: String, Codable, Equatable, Sendable {
    case idle
    case loading
    case available
    case error
    case unsupported
}
