import Foundation

struct SwitchAccountRestartCoordinator: Sendable {
    let appController: CodexAppControlling
    let preferencesPort: CodexAgentPreferencesPorting

    func restartIfRequested(
        restartCodexApp: Bool,
        shouldRestartCodexApp: Bool,
        preserveEnabled: Bool,
        wasAlreadyActive: Bool,
        targetPreferences: AccountAgentPreferences?,
        warningBox: SwitchAccountWarningBox
    ) async -> SwitchAccountRestartResult {
        guard restartCodexApp else {
            return .skipped
        }

        guard shouldRestartCodexApp else {
            return SwitchAccountRestartResult(
                outcome: .wasNotRunning,
                failureReason: nil,
                appliedAgentPreferences: false
            )
        }

        let preferencesPort = preferencesPort
        let targetPreferences = preservedPreferences(
            preserveEnabled: preserveEnabled,
            wasAlreadyActive: wasAlreadyActive,
            targetPreferences: targetPreferences
        )

        do {
            let outcome = try await appController.restartIfRunning {
                await SwitchAccountLocalStatePreserver(
                    preferencesPort: preferencesPort,
                    warningBox: warningBox
                ).apply(targetPreferences: targetPreferences)
            }
            return SwitchAccountRestartResult(
                outcome: outcome,
                failureReason: nil,
                appliedAgentPreferences: Self.appliedAgentPreferences(
                    outcome: outcome,
                    warningBox: warningBox
                )
            )
        } catch {
            return SwitchAccountRestartResult(
                outcome: nil,
                failureReason: Self.codexAppRestartFailureReason(from: error),
                appliedAgentPreferences: false
            )
        }
    }

    private func preservedPreferences(
        preserveEnabled: Bool,
        wasAlreadyActive: Bool,
        targetPreferences: AccountAgentPreferences?
    ) -> AccountAgentPreferences? {
        guard preserveEnabled,
              !wasAlreadyActive,
              targetPreferences?.isEmpty == false
        else {
            return nil
        }
        return targetPreferences
    }
}
