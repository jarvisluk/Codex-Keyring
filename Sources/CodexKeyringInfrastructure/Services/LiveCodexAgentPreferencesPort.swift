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

    let tomlEditor: CodexConfigTomlEditor
    let stateEditor: CodexGlobalStateEditor
    let fileStore: CodexAgentPreferencesFileStore
    let log = CodexKeyringLog.makeAppLogger(.agentPrefs)
    let ioQueue: DispatchQueue

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
        self.fileStore = CodexAgentPreferencesFileStore(
            configTomlURL: configTomlURL,
            globalStateURL: globalStateURL
        )
        self.ioQueue = ioQueue
    }

    static let atomStateRoot = "electron-persisted-atom-state"
    static let agentModePath = [atomStateRoot, "agent-mode-by-host-id", "local"]
    static let skipConfirmPath = [atomStateRoot, "skip-full-access-confirm"]
    static let sidebarOrganizeModePath = [atomStateRoot, "sidebar-organize-mode-v1"]
    static let projectOrderPath = ["project-order"]
    static let pinnedProjectIDsPath = ["pinned-project-ids"]

    func performIO<T: Sendable>(
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
}
