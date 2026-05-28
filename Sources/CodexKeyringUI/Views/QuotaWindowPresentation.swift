import SwiftUI
import CodexKeyringDomain

enum QuotaWindowTint: Equatable {
    case secondary
    case ready
    case low
    case blocked

    var color: Color {
        switch self {
        case .secondary:
            return .secondary
        case .ready:
            return .green
        case .low:
            return .orange
        case .blocked:
            return .red
        }
    }
}

struct QuotaWindowPresentation: Equatable {
    let durationLabel: String
    let remainingText: String
    let remainingPercent: Double
    let resetText: String
    let remainingTextTint: QuotaWindowTint
    let progressTint: QuotaWindowTint

    init(window: QuotaWindow, now: Date = Date()) {
        durationLabel = window.durationLabel
        remainingText = "\(window.formattedRemaining) left"
        remainingPercent = window.remainingPercent
        resetText = window.formattedReset(now: now)
        remainingTextTint = window.remainingPercent <= 15 ? .low : .secondary
        if window.remainingPercent <= 5 {
            progressTint = .blocked
        } else if window.remainingPercent <= 15 {
            progressTint = .low
        } else {
            progressTint = .ready
        }
    }
}

extension QuotaWindow {
    var formattedRemaining: String {
        "\(Int(remainingPercent.rounded()))%"
    }

    var compactDurationLabel: String {
        guard let minutes = windowDurationMinutes else { return "limit" }
        switch minutes {
        case 5 * 60:
            return "5h"
        case 7 * 24 * 60:
            return "week"
        default:
            return durationLabel.lowercased()
        }
    }

    var formattedReset: String {
        formattedReset(now: Date())
    }

    func formattedReset(now: Date) -> String {
        guard let resetsAt else { return "reset unknown" }
        if resetsAt <= now {
            return "resets now"
        }
        let relative = resetsAt.formatted(.relative(presentation: .numeric))
        return "resets \(relative)"
    }
}
