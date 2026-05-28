import Foundation

extension CodexAgentPreferencesFileStore {
    func writeConfig(text: String) throws {
        try writeAtomically(data: Data(text.utf8), to: configTomlURL)
    }

    func writeGlobalState(data: Data) throws {
        try writeAtomically(data: data, to: globalStateURL)
    }

    private func writeAtomically(data: Data, to destination: URL) throws {
        try ensureDirectoryExists(containing: destination)
        let tmp = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).codex-keyring-\(UUID().uuidString)")
        do {
            try data.write(to: tmp, options: [.atomic])
            try PrivateFilePermissions.setFile(at: tmp, fileManager: fileManager)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: destination)
            }
            try PrivateFilePermissions.setFile(at: destination, fileManager: fileManager)
        } catch {
            try? fileManager.removeItem(at: tmp)
            throw error
        }
    }

    private func ensureDirectoryExists(containing url: URL) throws {
        try PrivateFilePermissions.createDirectory(
            at: url.deletingLastPathComponent(),
            fileManager: fileManager
        )
    }
}
