import Foundation

public struct QuotaWindow: Codable, Equatable, Sendable {
    public var usedPercent: Double
    public var windowDurationMinutes: Int?
    public var resetsAt: Date?

    public init(
        usedPercent: Double,
        windowDurationMinutes: Int?,
        resetsAt: Date?
    ) {
        self.usedPercent = usedPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Double {
        max(0, min(100, 100 - usedPercent))
    }

    public var durationLabel: String {
        QuotaWindowDurationLabel.label(minutes: windowDurationMinutes)
    }
}
