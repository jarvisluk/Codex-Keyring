import Foundation

struct LogRecordFormatter {
    private let formatter: ISO8601DateFormatter

    init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
    }

    func format(_ record: LogRecord) -> String {
        let timestamp = formatter.string(from: record.timestamp)
        let level = record.level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0)
        let category = record.category.padding(toLength: 14, withPad: " ", startingAt: 0)
        let safeMessage = record.message
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return "\(timestamp) [\(level)] \(category) \(safeMessage)\n"
    }
}
