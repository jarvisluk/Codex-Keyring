import Foundation
import CodexKeyringDomain

/// `CodexAgentPreferencesPorting` implementation that reads and writes the
/// live `~/.codex/config.toml` and `~/.codex/.codex-global-state.json` files.
///
/// Writes are atomic via a `.tmp-<uuid>` sibling + `replaceItemAt`. Reads
/// gracefully degrade to "no preferences" when either file is missing or
/// unreadable.
public struct LiveCodexAgentPreferencesPort: CodexAgentPreferencesPorting {
    public let configTomlURL: URL
    public let globalStateURL: URL

    private let tomlEditor: CodexConfigTomlEditor
    private let stateEditor: CodexGlobalStateEditor
    private let log = CodexKeyringLog.makeAppLogger(.agentPrefs)
    private var fileManager: FileManager { .default }

    public init(
        configTomlURL: URL = AppPaths.codexConfigTomlFile,
        globalStateURL: URL = AppPaths.codexGlobalStateFile,
        tomlEditor: CodexConfigTomlEditor = CodexConfigTomlEditor(),
        stateEditor: CodexGlobalStateEditor = CodexGlobalStateEditor()
    ) {
        self.configTomlURL = configTomlURL
        self.globalStateURL = globalStateURL
        self.tomlEditor = tomlEditor
        self.stateEditor = stateEditor
    }

    // MARK: - Paths inside the global-state JSON

    private static let atomStateRoot = "electron-persisted-atom-state"
    private static let agentModePath = [atomStateRoot, "agent-mode-by-host-id", "local"]
    private static let skipConfirmPath = [atomStateRoot, "skip-full-access-confirm"]
    private static let sidebarOrganizeModePath = [atomStateRoot, "sidebar-organize-mode-v1"]
    private static let projectOrderPath = ["project-order"]
    private static let pinnedProjectIDsPath = ["pinned-project-ids"]

    // MARK: - Capture

    public func captureCurrent() async throws -> AccountAgentPreferences {
        var prefs = AccountAgentPreferences()

        if let tomlText = try? String(contentsOf: configTomlURL, encoding: .utf8) {
            prefs.model = tomlEditor.readString("model", in: tomlText)
            prefs.modelReasoningEffort = tomlEditor.readString("model_reasoning_effort", in: tomlText)
            prefs.approvalPolicy = tomlEditor.readString("approval_policy", in: tomlText)
            prefs.approvalsReviewer = tomlEditor.readString("approvals_reviewer", in: tomlText)
            prefs.sandboxMode = tomlEditor.readString("sandbox_mode", in: tomlText)
        } else {
            log.debug("config.toml missing or unreadable at \(self.configTomlURL.path); skipping toml capture")
        }

        if let stateData = try? Data(contentsOf: globalStateURL) {
            prefs.agentMode = stateEditor.readString(at: Self.agentModePath, in: stateData)
            prefs.skipFullAccessConfirm = stateEditor.readBool(at: Self.skipConfirmPath, in: stateData)
        } else {
            log.debug("global-state.json missing or unreadable at \(self.globalStateURL.path); skipping json capture")
        }

        log.info("captured agent preferences \(prefs.summary)")
        return prefs
    }

    // MARK: - Apply

    public func apply(_ preferences: AccountAgentPreferences) async throws {
        guard !preferences.isEmpty else {
            log.debug("apply skipped: no non-nil fields")
            return
        }

        try writeTomlUpdates(from: preferences)
        try writeStateUpdates(from: preferences)

        log.info("applied agent preferences \(preferences.summary)")
    }

    // MARK: - Project arrangement

    public func captureProjectArrangement() async throws -> CodexProjectArrangement {
        guard let stateData = try? Data(contentsOf: globalStateURL) else {
            log.debug("global-state.json missing or unreadable at \(self.globalStateURL.path); skipping project arrangement capture")
            return CodexProjectArrangement()
        }

        let arrangement = CodexProjectArrangement(
            projectOrder: stateEditor.readStringArray(at: Self.projectOrderPath, in: stateData),
            pinnedProjectIDs: stateEditor.readStringArray(at: Self.pinnedProjectIDsPath, in: stateData),
            sidebarOrganizeMode: stateEditor.readString(at: Self.sidebarOrganizeModePath, in: stateData)
        )
        log.info("captured project arrangement \(arrangement.summary)")
        return arrangement
    }

    public func restoreProjectArrangement(_ arrangement: CodexProjectArrangement) async throws {
        guard !arrangement.isEmpty else {
            log.debug("project arrangement restore skipped: no captured fields")
            return
        }

        try ensureCodexDirectoryExists()

        var data: Data
        if fileManager.fileExists(atPath: globalStateURL.path) {
            data = try Data(contentsOf: globalStateURL)
        } else {
            data = Data("{}".utf8)
        }

        if let projectOrder = arrangement.projectOrder {
            data = try stateEditor.writing(projectOrder, at: Self.projectOrderPath, in: data)
        }
        if let pinnedProjectIDs = arrangement.pinnedProjectIDs {
            data = try stateEditor.writing(pinnedProjectIDs, at: Self.pinnedProjectIDsPath, in: data)
        }
        if let sidebarOrganizeMode = arrangement.sidebarOrganizeMode {
            data = try stateEditor.writing(sidebarOrganizeMode, at: Self.sidebarOrganizeModePath, in: data)
        }

        try writeAtomically(data: data, to: globalStateURL)
        log.info("restored project arrangement \(arrangement.summary)")
    }

    // MARK: - TOML write

    private func writeTomlUpdates(from prefs: AccountAgentPreferences) throws {
        var updates: [String: CodexConfigTomlEditor.ScalarValue?] = [:]
        if let v = prefs.model { updates["model"] = .string(v) }
        if let v = prefs.modelReasoningEffort { updates["model_reasoning_effort"] = .string(v) }
        if let v = prefs.approvalPolicy { updates["approval_policy"] = .string(v) }
        if let v = prefs.approvalsReviewer { updates["approvals_reviewer"] = .string(v) }
        if let v = prefs.sandboxMode { updates["sandbox_mode"] = .string(v) }

        guard !updates.isEmpty else { return }

        try ensureCodexDirectoryExists()

        let originalText = (try? String(contentsOf: configTomlURL, encoding: .utf8)) ?? ""
        let updatedText = tomlEditor.applying(updates, to: originalText)
        if updatedText == originalText {
            log.debug("config.toml unchanged after applying updates")
            return
        }
        try writeAtomically(text: updatedText, to: configTomlURL)
    }

    // MARK: - global-state write

    private func writeStateUpdates(from prefs: AccountAgentPreferences) throws {
        let hasJsonUpdates = prefs.agentMode != nil || prefs.skipFullAccessConfirm != nil
        guard hasJsonUpdates else { return }

        try ensureCodexDirectoryExists()

        var data: Data
        if fileManager.fileExists(atPath: globalStateURL.path) {
            data = try Data(contentsOf: globalStateURL)
        } else {
            // Codex App will lazily create this when it next quits, so writing
            // a fresh `{}` is safe and ensures our preferences survive until
            // then.
            data = Data("{}".utf8)
        }

        if let agentMode = prefs.agentMode {
            data = try stateEditor.writing(agentMode, at: Self.agentModePath, in: data)
        }
        if let skipConfirm = prefs.skipFullAccessConfirm {
            // NSNumber bridging keeps the JSON literal as `true`/`false`.
            data = try stateEditor.writing(NSNumber(value: skipConfirm), at: Self.skipConfirmPath, in: data)
        }

        try writeAtomically(data: data, to: globalStateURL)
    }

    // MARK: - File helpers

    private func ensureCodexDirectoryExists() throws {
        let dir = configTomlURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func writeAtomically(text: String, to destination: URL) throws {
        try writeAtomically(data: Data(text.utf8), to: destination)
    }

    private func writeAtomically(data: Data, to destination: URL) throws {
        let tmp = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).codex-keyring-\(UUID().uuidString)")
        do {
            try data.write(to: tmp, options: [.atomic])
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: tmp)
            throw error
        }
    }
}

private extension AccountAgentPreferences {
    /// Compact human-readable summary for logs. Never includes anything that
    /// looks like a secret (the captured fields are all plain enum-like
    /// strings or booleans).
    var summary: String {
        var parts: [String] = []
        if let model { parts.append("model=\(model)") }
        if let modelReasoningEffort { parts.append("effort=\(modelReasoningEffort)") }
        if let approvalPolicy { parts.append("approval=\(approvalPolicy)") }
        if let approvalsReviewer { parts.append("reviewer=\(approvalsReviewer)") }
        if let sandboxMode { parts.append("sandbox=\(sandboxMode)") }
        if let agentMode { parts.append("agentMode=\(agentMode)") }
        if let skipFullAccessConfirm { parts.append("skipConfirm=\(skipFullAccessConfirm)") }
        return "[\(parts.joined(separator: ", "))]"
    }
}

private extension CodexProjectArrangement {
    var summary: String {
        var parts: [String] = []
        if let projectOrder { parts.append("projectOrder=\(projectOrder.count)") }
        if let pinnedProjectIDs { parts.append("pinned=\(pinnedProjectIDs.count)") }
        if let sidebarOrganizeMode { parts.append("sidebarMode=\(sidebarOrganizeMode)") }
        return "[\(parts.joined(separator: ", "))]"
    }
}
