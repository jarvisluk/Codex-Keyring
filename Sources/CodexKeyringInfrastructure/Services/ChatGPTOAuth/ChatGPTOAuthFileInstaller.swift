import Foundation
import CodexKeyringDomain

struct ChatGPTOAuthFileInstaller {
    let authFileURL: URL
    let codexDirectory: URL
    var fileManager: FileManager { .default }

    func install(data: Data) throws {
        let temporaryURL = codexDirectory
            .appendingPathComponent(".auth.json.codex-keyring-\(UUID().uuidString)")

        try ensureAuthDestinationIsFileIfPresent()
        try prepareCodexDirectory()
        try stage(data, at: temporaryURL)
        try installStagedFile(from: temporaryURL)
    }

    private func ensureAuthDestinationIsFileIfPresent() throws {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: authFileURL.path, isDirectory: &isDirectory) else {
            return
        }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Auth destination is not a file: \(authFileURL.path)"
            )
        }
    }

    private func prepareCodexDirectory() throws {
        do {
            try PrivateFilePermissions.createDirectory(at: codexDirectory, fileManager: fileManager)
        } catch {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not prepare \(codexDirectory.path): \(error.localizedDescription)"
            )
        }
    }

    private func stage(_ data: Data, at temporaryURL: URL) throws {
        do {
            try data.write(to: temporaryURL, options: [.atomic])
            try PrivateFilePermissions.setFile(at: temporaryURL, fileManager: fileManager)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not stage auth.json: \(error.localizedDescription)"
            )
        }
    }

    private func installStagedFile(from temporaryURL: URL) throws {
        do {
            if fileManager.fileExists(atPath: authFileURL.path) {
                _ = try fileManager.replaceItemAt(authFileURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: authFileURL)
            }
            try PrivateFilePermissions.setFile(at: authFileURL, fileManager: fileManager)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not install auth.json: \(error.localizedDescription)"
            )
        }
    }
}
