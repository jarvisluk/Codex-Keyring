import Foundation
import CodexKeyringDomain

/// `CodexAuthInstalling` that copies/replaces `~/.codex/auth.json` atomically
/// and writes timestamped backups under the configured backups directory.
public final class LiveCodexAuthInstaller: CodexAuthInstalling, @unchecked Sendable {
    public let liveAuthFileURL: URL
    public let codexDirectory: URL
    public let backupsDirectory: URL
    public let loginStagingDirectory: URL

    let log = CodexKeyringLog.makeAppLogger(.installer)
    var fileManager: FileManager { .default }
    let clock: Clock
    let ioQueue: DispatchQueue

    public init(
        liveAuthFileURL: URL = AppPaths.codexAuthFile,
        codexDirectory: URL = AppPaths.codexDirectory,
        backupsDirectory: URL = AppPaths.backupsDirectory,
        loginStagingDirectory: URL = AppPaths.loginStagingDirectory,
        clock: Clock = SystemClock(),
        ioQueue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.AuthInstaller")
    ) {
        self.liveAuthFileURL = liveAuthFileURL
        self.codexDirectory = codexDirectory
        self.backupsDirectory = backupsDirectory
        self.loginStagingDirectory = loginStagingDirectory
        self.clock = clock
        self.ioQueue = ioQueue
    }

    public func install(snapshot: URL) async throws {
        try await performIO {
            try self.requireAuthFile(at: snapshot, role: "Snapshot")
            do {
                try self.fileManager.createDirectory(at: self.codexDirectory, withIntermediateDirectories: true)
                try self.setPrivateDirectoryPermissions(at: self.codexDirectory)
            } catch {
                throw CodexKeyringError.fileSystemFailure(reason: "Could not prepare ~/.codex: \(error.localizedDescription)")
            }
            let tmp = self.codexDirectory.appendingPathComponent(".auth.json.codex-switcher-\(UUID().uuidString)")
            do {
                _ = try self.authFileExists(at: self.liveAuthFileURL, role: "Live auth path")
                try self.fileManager.copyItem(at: snapshot, to: tmp)
                try self.setPrivateFilePermissions(at: tmp)
                if self.fileManager.fileExists(atPath: self.liveAuthFileURL.path) {
                    _ = try self.fileManager.replaceItemAt(self.liveAuthFileURL, withItemAt: tmp)
                } else {
                    try self.fileManager.moveItem(at: tmp, to: self.liveAuthFileURL)
                }
                try self.setPrivateFilePermissions(at: self.liveAuthFileURL)
                self.log.info("installed snapshot \(snapshot.lastPathComponent)")
            } catch {
                try? self.fileManager.removeItem(at: tmp)
                throw CodexKeyringError.fileSystemFailure(reason: "Could not install snapshot: \(error.localizedDescription)")
            }
        }
    }
}
