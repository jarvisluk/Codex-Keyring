import Foundation

struct SwitchAccountPreferenceCapture: Sendable {
    let preferencesPort: CodexAgentPreferencesPorting

    /// Capture the OUTGOING account's current Codex agent preferences so any
    /// tweaks the user made in Codex App carry over the next time they switch
    /// back. Capture only runs when Codex App will be restarted; otherwise the
    /// snapshot may be stale by the time Codex App next quits and rewrites files.
    func captureOutgoingIfNeeded(
        manifest: inout AccountManifest,
        preserveEnabled: Bool,
        wasAlreadyActive: Bool,
        warningBox: SwitchAccountWarningBox
    ) async {
        guard preserveEnabled,
              !wasAlreadyActive,
              let previousActiveID = manifest.activeAccountID,
              let previousIdx = manifest.accounts.firstIndex(where: { $0.id == previousActiveID })
        else {
            return
        }

        do {
            let captured = try await preferencesPort.captureCurrent()
            if !captured.isEmpty {
                manifest.accounts[previousIdx].agentPreferences = captured
            }
        } catch {
            warningBox.recordAgentPreferencesWarning(error.localizedDescription)
        }
    }
}
