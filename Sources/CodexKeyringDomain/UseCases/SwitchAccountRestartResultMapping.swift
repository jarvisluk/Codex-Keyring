import Foundation

extension SwitchAccountRestartCoordinator {
    static func appliedAgentPreferences(
        outcome: CodexAppRestartOutcome,
        warningBox: SwitchAccountWarningBox
    ) -> Bool {
        if case .relaunched = outcome {
            return warningBox.appliedAgentPreferences
        }
        return false
    }

    static func codexAppRestartFailureReason(from error: Error) -> String {
        if case CodexKeyringError.codexAppRelaunchFailed(let reason) = error {
            return reason
        }
        return error.localizedDescription
    }
}
