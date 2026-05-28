import Foundation
import CodexKeyringDomain

extension LiveCodexAgentPreferencesPort {
    public func captureCurrent() async throws -> AccountAgentPreferences {
        try await performIO {
            var prefs = AccountAgentPreferences()

            if let tomlText = try self.fileStore.readConfigTextIfPresent() {
                prefs.model = self.tomlEditor.readString("model", in: tomlText)
                prefs.modelReasoningEffort = self.tomlEditor.readString("model_reasoning_effort", in: tomlText)
                prefs.approvalPolicy = self.tomlEditor.readString("approval_policy", in: tomlText)
                prefs.approvalsReviewer = self.tomlEditor.readString("approvals_reviewer", in: tomlText)
                prefs.sandboxMode = self.tomlEditor.readString("sandbox_mode", in: tomlText)
            } else {
                self.log.debug("config.toml missing at \(self.configTomlURL.path); skipping toml capture")
            }

            if let stateData = try self.fileStore.readGlobalStateDataIfPresent() {
                prefs.agentMode = self.stateEditor.readString(at: Self.agentModePath, in: stateData)
                prefs.skipFullAccessConfirm = self.stateEditor.readBool(at: Self.skipConfirmPath, in: stateData)
            } else {
                self.log.debug("global-state.json missing at \(self.globalStateURL.path); skipping json capture")
            }

            self.log.info("captured agent preferences \(prefs.liveAgentPreferencesSummary)")
            return prefs
        }
    }
}
