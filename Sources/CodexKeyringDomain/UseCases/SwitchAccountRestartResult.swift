import Foundation

struct SwitchAccountRestartResult: Sendable {
    var outcome: CodexAppRestartOutcome?
    var failureReason: String?
    var appliedAgentPreferences: Bool

    static let skipped = SwitchAccountRestartResult(
        outcome: nil,
        failureReason: nil,
        appliedAgentPreferences: false
    )
}
