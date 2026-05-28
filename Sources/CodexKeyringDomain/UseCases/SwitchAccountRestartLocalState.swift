import Foundation

struct SwitchAccountLocalStatePreserver: Sendable {
    let preferencesPort: CodexAgentPreferencesPorting
    let warningBox: SwitchAccountWarningBox

    func apply(targetPreferences: AccountAgentPreferences?) async {
        let projectArrangement = await capturedProjectArrangement(
            preferencesPort: preferencesPort
        )

        await applyAgentPreferencesIfPresent(
            targetPreferences,
            preferencesPort: preferencesPort
        )

        await restoreProjectArrangementIfPresent(
            projectArrangement,
            preferencesPort: preferencesPort
        )
    }

    private func capturedProjectArrangement(
        preferencesPort: CodexAgentPreferencesPorting
    ) async -> CodexProjectArrangement {
        do {
            return try await preferencesPort.captureProjectArrangement()
        } catch {
            warningBox.recordProjectArrangementWarning(error.localizedDescription)
            return CodexProjectArrangement()
        }
    }

    private func applyAgentPreferencesIfPresent(
        _ targetPreferences: AccountAgentPreferences?,
        preferencesPort: CodexAgentPreferencesPorting
    ) async {
        guard let targetPreferences else { return }
        do {
            try await preferencesPort.apply(targetPreferences)
            warningBox.recordAppliedAgentPreferences()
        } catch {
            warningBox.recordAgentPreferencesWarning(error.localizedDescription)
        }
    }

    private func restoreProjectArrangementIfPresent(
        _ projectArrangement: CodexProjectArrangement,
        preferencesPort: CodexAgentPreferencesPorting
    ) async {
        guard !projectArrangement.isEmpty else { return }
        do {
            try await preferencesPort.restoreProjectArrangement(projectArrangement)
        } catch {
            warningBox.recordProjectArrangementWarning(error.localizedDescription)
        }
    }
}
