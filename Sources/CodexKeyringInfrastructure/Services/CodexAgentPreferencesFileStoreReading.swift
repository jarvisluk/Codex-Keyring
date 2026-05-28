import Foundation
import CodexKeyringDomain

extension CodexAgentPreferencesFileStore {
    func readConfigTextIfPresent() throws -> String? {
        try readTextIfPresent(configTomlURL, label: "config.toml")
    }

    func readGlobalStateDataIfPresent() throws -> Data? {
        try readDataIfPresent(globalStateURL, label: "global-state.json")
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
}
