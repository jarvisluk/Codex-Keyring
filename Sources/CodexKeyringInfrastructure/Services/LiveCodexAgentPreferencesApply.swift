import Foundation
import CodexKeyringDomain

extension LiveCodexAgentPreferencesPort {
    public func apply(_ preferences: AccountAgentPreferences) async throws {
        try await performIO {
            guard !preferences.isEmpty else {
                self.log.debug("apply skipped: no non-nil fields")
                return
            }

            let tomlUpdate = try self.preparedTomlUpdate(from: preferences)
            let stateUpdate = try self.preparedStateUpdate(from: preferences)

            if let tomlUpdate {
                try self.fileStore.writeConfig(text: tomlUpdate)
            }
            if let stateUpdate {
                try self.fileStore.writeGlobalState(data: stateUpdate)
            }

            self.log.info("applied agent preferences \(preferences.liveAgentPreferencesSummary)")
        }
    }

    private func preparedTomlUpdate(from prefs: AccountAgentPreferences) throws -> String? {
        var updates: [String: CodexConfigTomlEditor.ScalarValue?] = [:]
        if let v = prefs.model { updates["model"] = .string(v) }
        if let v = prefs.modelReasoningEffort { updates["model_reasoning_effort"] = .string(v) }
        if let v = prefs.approvalPolicy { updates["approval_policy"] = .string(v) }
        if let v = prefs.approvalsReviewer { updates["approvals_reviewer"] = .string(v) }
        if let v = prefs.sandboxMode { updates["sandbox_mode"] = .string(v) }

        guard !updates.isEmpty else { return nil }

        let originalText = try fileStore.readConfigTextIfPresent() ?? ""
        let updatedText = tomlEditor.applying(updates, to: originalText)
        if updatedText == originalText {
            log.debug("config.toml unchanged after applying updates")
            return nil
        }
        return updatedText
    }

    private func preparedStateUpdate(from prefs: AccountAgentPreferences) throws -> Data? {
        let hasJsonUpdates = prefs.agentMode != nil || prefs.skipFullAccessConfirm != nil
        guard hasJsonUpdates else { return nil }

        // Codex App will lazily create this when it next quits, so writing a
        // fresh `{}` is safe when the file is simply missing.
        var data = try fileStore.readGlobalStateDataIfPresent() ?? Data("{}".utf8)

        if let agentMode = prefs.agentMode {
            data = try stateEditor.writing(agentMode, at: Self.agentModePath, in: data)
        }
        if let skipConfirm = prefs.skipFullAccessConfirm {
            // NSNumber bridging keeps the JSON literal as `true`/`false`.
            data = try stateEditor.writing(NSNumber(value: skipConfirm), at: Self.skipConfirmPath, in: data)
        }

        return data
    }
}
