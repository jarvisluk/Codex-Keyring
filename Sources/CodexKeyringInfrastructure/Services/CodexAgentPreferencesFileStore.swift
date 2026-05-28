import Foundation
import CodexKeyringDomain

struct CodexAgentPreferencesFileStore {
    let configTomlURL: URL
    let globalStateURL: URL
    let fileManager: FileManager

    init(
        configTomlURL: URL,
        globalStateURL: URL,
        fileManager: FileManager = .default
    ) {
        self.configTomlURL = configTomlURL
        self.globalStateURL = globalStateURL
        self.fileManager = fileManager
    }

    func ensureCodexDirectoryExists() throws {
        try PrivateFilePermissions.createDirectory(
            at: configTomlURL.deletingLastPathComponent(),
            fileManager: fileManager
        )
    }
}
