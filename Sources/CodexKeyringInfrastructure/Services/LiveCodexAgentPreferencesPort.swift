import Foundation
import CodexKeyringDomain

/// `CodexAgentPreferencesPorting` implementation that reads and writes the
/// live `~/.codex/config.toml` and `~/.codex/.codex-global-state.json` files.
///
/// Writes are atomic via a `.tmp-<uuid>` sibling + `replaceItemAt`. Reads
/// gracefully degrade to "no preferences" when either file is missing, but
/// surface a real error when a file exists and cannot be read.
public final class LiveCodexAgentPreferencesPort: CodexAgentPreferencesPorting, @unchecked Sendable {
    public let configTomlURL: URL
    public let globalStateURL: URL

    private let tomlEditor: CodexConfigTomlEditor
    private let stateEditor: CodexGlobalStateEditor
    private let log = CodexKeyringLog.makeAppLogger(.agentPrefs)
    private let ioQueue: DispatchQueue
    private var fileManager: FileManager { .default }

    public init(
        configTomlURL: URL = AppPaths.codexConfigTomlFile,
        globalStateURL: URL = AppPaths.codexGlobalStateFile,
        tomlEditor: CodexConfigTomlEditor = CodexConfigTomlEditor(),
        stateEditor: CodexGlobalStateEditor = CodexGlobalStateEditor(),
        ioQueue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.AgentPreferences")
    ) {
        self.configTomlURL = configTomlURL
        self.globalStateURL = globalStateURL
        self.tomlEditor = tomlEditor
        self.stateEditor = stateEditor
        self.ioQueue = ioQueue
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
        try await performIO {
            var prefs = AccountAgentPreferences()

            if let tomlText = try self.readTextIfPresent(self.configTomlURL, label: "config.toml") {
                prefs.model = self.tomlEditor.readString("model", in: tomlText)
                prefs.modelReasoningEffort = self.tomlEditor.readString("model_reasoning_effort", in: tomlText)
                prefs.approvalPolicy = self.tomlEditor.readString("approval_policy", in: tomlText)
                prefs.approvalsReviewer = self.tomlEditor.readString("approvals_reviewer", in: tomlText)
                prefs.sandboxMode = self.tomlEditor.readString("sandbox_mode", in: tomlText)
            } else {
                self.log.debug("config.toml missing at \(self.configTomlURL.path); skipping toml capture")
            }

            if let stateData = try self.readDataIfPresent(self.globalStateURL, label: "global-state.json") {
                prefs.agentMode = self.stateEditor.readString(at: Self.agentModePath, in: stateData)
                prefs.skipFullAccessConfirm = self.stateEditor.readBool(at: Self.skipConfirmPath, in: stateData)
            } else {
                self.log.debug("global-state.json missing at \(self.globalStateURL.path); skipping json capture")
            }

            self.log.info("captured agent preferences \(prefs.summary)")
            return prefs
        }
    }

    // MARK: - Apply

    public func apply(_ preferences: AccountAgentPreferences) async throws {
        try await performIO {
            guard !preferences.isEmpty else {
                self.log.debug("apply skipped: no non-nil fields")
                return
            }

            let tomlUpdate = try self.preparedTomlUpdate(from: preferences)
            let stateUpdate = try self.preparedStateUpdate(from: preferences)

            if let tomlUpdate {
                try self.writeAtomically(text: tomlUpdate, to: self.configTomlURL)
            }
            if let stateUpdate {
                try self.writeAtomically(data: stateUpdate, to: self.globalStateURL)
            }

            self.log.info("applied agent preferences \(preferences.summary)")
        }
    }

    // MARK: - Project arrangement

    public func captureProjectArrangement() async throws -> CodexProjectArrangement {
        try await performIO {
            guard let stateData = try self.readDataIfPresent(self.globalStateURL, label: "global-state.json") else {
                self.log.debug("global-state.json missing at \(self.globalStateURL.path); skipping project arrangement capture")
                return CodexProjectArrangement()
            }

            let arrangement = CodexProjectArrangement(
                projectOrder: self.stateEditor.readStringArray(at: Self.projectOrderPath, in: stateData),
                pinnedProjectIDs: self.stateEditor.readStringArray(at: Self.pinnedProjectIDsPath, in: stateData),
                sidebarOrganizeMode: self.stateEditor.readString(at: Self.sidebarOrganizeModePath, in: stateData)
            )
            self.log.info("captured project arrangement \(arrangement.summary)")
            return arrangement
        }
    }

    public func restoreProjectArrangement(_ arrangement: CodexProjectArrangement) async throws {
        try await performIO {
            guard !arrangement.isEmpty else {
                self.log.debug("project arrangement restore skipped: no captured fields")
                return
            }

            try self.ensureCodexDirectoryExists()

            var data = try self.readDataIfPresent(self.globalStateURL, label: "global-state.json") ?? Data("{}".utf8)

            if let projectOrder = arrangement.projectOrder {
                data = try self.stateEditor.writing(projectOrder, at: Self.projectOrderPath, in: data)
            }
            if let pinnedProjectIDs = arrangement.pinnedProjectIDs {
                data = try self.stateEditor.writing(pinnedProjectIDs, at: Self.pinnedProjectIDsPath, in: data)
            }
            if let sidebarOrganizeMode = arrangement.sidebarOrganizeMode {
                data = try self.stateEditor.writing(sidebarOrganizeMode, at: Self.sidebarOrganizeModePath, in: data)
            }

            try self.writeAtomically(data: data, to: self.globalStateURL)
            self.log.info("restored project arrangement \(arrangement.summary)")
        }
    }

    // MARK: - TOML write

    private func preparedTomlUpdate(from prefs: AccountAgentPreferences) throws -> String? {
        var updates: [String: CodexConfigTomlEditor.ScalarValue?] = [:]
        if let v = prefs.model { updates["model"] = .string(v) }
        if let v = prefs.modelReasoningEffort { updates["model_reasoning_effort"] = .string(v) }
        if let v = prefs.approvalPolicy { updates["approval_policy"] = .string(v) }
        if let v = prefs.approvalsReviewer { updates["approvals_reviewer"] = .string(v) }
        if let v = prefs.sandboxMode { updates["sandbox_mode"] = .string(v) }

        guard !updates.isEmpty else { return nil }

        let originalText = try readTextIfPresent(configTomlURL, label: "config.toml") ?? ""
        let updatedText = tomlEditor.applying(updates, to: originalText)
        if updatedText == originalText {
            log.debug("config.toml unchanged after applying updates")
            return nil
        }
        return updatedText
    }

    // MARK: - global-state write

    private func preparedStateUpdate(from prefs: AccountAgentPreferences) throws -> Data? {
        let hasJsonUpdates = prefs.agentMode != nil || prefs.skipFullAccessConfirm != nil
        guard hasJsonUpdates else { return nil }

        // Codex App will lazily create this when it next quits, so writing a
        // fresh `{}` is safe when the file is simply missing.
        var data = try readDataIfPresent(globalStateURL, label: "global-state.json") ?? Data("{}".utf8)

        if let agentMode = prefs.agentMode {
            data = try stateEditor.writing(agentMode, at: Self.agentModePath, in: data)
        }
        if let skipConfirm = prefs.skipFullAccessConfirm {
            // NSNumber bridging keeps the JSON literal as `true`/`false`.
            data = try stateEditor.writing(NSNumber(value: skipConfirm), at: Self.skipConfirmPath, in: data)
        }

        return data
    }

    private func performIO<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - File helpers

    private func ensureCodexDirectoryExists() throws {
        let dir = configTomlURL.deletingLastPathComponent()
        try PrivateFilePermissions.createDirectory(at: dir, fileManager: fileManager)
    }

    private func readTextIfPresent(_ url: URL, label: String) throws -> String? {
        guard try existingRegularFile(url, label: label) else { return nil }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not read \(label) at \(url.path): \(error.localizedDescription)"
            )
        }
    }

    private func readDataIfPresent(_ url: URL, label: String) throws -> Data? {
        guard try existingRegularFile(url, label: label) else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not read \(label) at \(url.path): \(error.localizedDescription)"
            )
        }
    }

    private func existingRegularFile(_ url: URL, label: String) throws -> Bool {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Expected \(label) to be a file, but found a directory at \(url.path)."
            )
        }
        return true
    }

    private func writeAtomically(text: String, to destination: URL) throws {
        try writeAtomically(data: Data(text.utf8), to: destination)
    }

    private func writeAtomically(data: Data, to destination: URL) throws {
        try ensureDirectoryExists(containing: destination)
        let tmp = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).codex-keyring-\(UUID().uuidString)")
        do {
            try data.write(to: tmp, options: [.atomic])
            try setPrivateFilePermissions(at: tmp)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: destination)
            }
            try setPrivateFilePermissions(at: destination)
        } catch {
            try? fileManager.removeItem(at: tmp)
            throw error
        }
    }

    private func setPrivateFilePermissions(at url: URL) throws {
        try PrivateFilePermissions.setFile(at: url, fileManager: fileManager)
    }

    private func ensureDirectoryExists(containing url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try PrivateFilePermissions.createDirectory(at: dir, fileManager: fileManager)
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
