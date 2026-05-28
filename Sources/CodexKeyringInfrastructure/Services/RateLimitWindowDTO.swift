import Foundation
import CodexKeyringDomain

struct RateLimitWindowDTO: Decodable {
    let usedPercent: Double?
    let limitWindowSeconds: Int?
    let resetAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case windowMinutes = "window_minutes"
        case resetAt = "reset_at"
        case resetsAt = "resets_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decodeIfPresent(Double.self, forKey: .usedPercent)
        if let limitWindowSeconds = try container.decodeIfPresent(Int.self, forKey: .limitWindowSeconds) {
            self.limitWindowSeconds = limitWindowSeconds
        } else if let windowMinutes = try container.decodeIfPresent(Int.self, forKey: .windowMinutes) {
            self.limitWindowSeconds = windowMinutes * 60
        } else {
            self.limitWindowSeconds = nil
        }
        resetAt = try container.decodeIfPresent(TimeInterval.self, forKey: .resetAt)
            ?? container.decodeIfPresent(TimeInterval.self, forKey: .resetsAt)
    }

    var asQuotaWindow: QuotaWindow? {
        guard let usedPercent else { return nil }
        let minutes = limitWindowSeconds.flatMap { seconds -> Int? in
            guard seconds > 0 else { return nil }
            return (seconds + 59) / 60
        }
        let resetDate = resetAt.map { Date(timeIntervalSince1970: $0) }
        return QuotaWindow(
            usedPercent: usedPercent,
            windowDurationMinutes: minutes,
            resetsAt: resetDate
        )
    }
}
