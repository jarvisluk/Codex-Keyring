import Foundation
import CodexKeyringDomain

/// `CodexAuthInstalling` that copies/replaces `~/.codex/auth.json` atomically
/// and writes timestamped backups under the configured backups directory.
public struct LiveCodexAuthInstaller: CodexAuthInstalling {
    public let liveAuthFileURL: URL
    public let codexDirectory: URL
    public let backupsDirectory: URL
    public let loginStagingDirectory: URL

    private let log = CodexKeyringLog.makeAppLogger(.installer)
    private var fileManager: FileManager { .default }
    private let clock: Clock

    public init(
        liveAuthFileURL: URL = AppPaths.codexAuthFile,
        codexDirectory: URL = AppPaths.codexDirectory,
        backupsDirectory: URL = AppPaths.backupsDirectory,
        loginStagingDirectory: URL = AppPaths.loginStagingDirectory,
        clock: Clock = SystemClock()
    ) {
        self.liveAuthFileURL = liveAuthFileURL
        self.codexDirectory = codexDirectory
        self.backupsDirectory = backupsDirectory
        self.loginStagingDirectory = loginStagingDirectory
        self.clock = clock
    }

    public func install(snapshot: URL) async throws {
        do {
            try fileManager.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        } catch {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not prepare ~/.codex: \(error.localizedDescription)")
        }
        let tmp = codexDirectory.appendingPathComponent(".auth.json.codex-switcher-\(UUID().uuidString)")
        do {
            try fileManager.copyItem(at: snapshot, to: tmp)
            if fileManager.fileExists(atPath: liveAuthFileURL.path) {
                _ = try fileManager.replaceItemAt(liveAuthFileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: liveAuthFileURL)
            }
            log.info("installed snapshot \(snapshot.lastPathComponent)")
        } catch {
            try? fileManager.removeItem(at: tmp)
            throw CodexKeyringError.fileSystemFailure(reason: "Could not install snapshot: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func backupCurrent() async throws -> URL? {
        guard fileManager.fileExists(atPath: liveAuthFileURL.path) else {
            log.debug("no live auth file to back up")
            return nil
        }
        do {
            try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
            let fileName = "auth-\(DisplayFormatters.fileTimestamp.string(from: clock.now())).json"
            let destination = backupsDirectory.appendingPathComponent(fileName)
            try fileManager.copyItem(at: liveAuthFileURL, to: destination)
            log.info("backed up live auth to \(fileName)")
            return destination
        } catch {
            throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
        }
    }

    public func stageLiveAuthIfPresent(prefix: String) async throws -> URL? {
        guard fileManager.fileExists(atPath: liveAuthFileURL.path) else {
            return nil
        }
        return try stageLiveAuth(prefix: prefix)
    }

    public func stageRequiredLiveAuth(prefix: String) async throws -> URL {
        guard fileManager.fileExists(atPath: liveAuthFileURL.path) else {
            throw CodexKeyringError.authFileMissing(liveAuthFileURL)
        }
        return try stageLiveAuth(prefix: prefix)
    }

    public func restoreLiveAuth(from stagedURL: URL?) async throws {
        if let stagedURL {
            try await install(snapshot: stagedURL)
        } else if fileManager.fileExists(atPath: liveAuthFileURL.path) {
            do {
                try fileManager.removeItem(at: liveAuthFileURL)
            } catch {
                throw CodexKeyringError.fileSystemFailure(reason: "Could not remove temporary live auth: \(error.localizedDescription)")
            }
        }
    }

    public func removeStagedAuth(_ url: URL?) async {
        guard let url else { return }
        try? fileManager.removeItem(at: url)
    }

    private func stageLiveAuth(prefix: String) throws -> URL {
        do {
            try fileManager.createDirectory(at: loginStagingDirectory, withIntermediateDirectories: true)
            let destination = loginStagingDirectory
                .appendingPathComponent("\(prefix)-\(UUID().uuidString).auth.json")
            try fileManager.copyItem(at: liveAuthFileURL, to: destination)
            return destination
        } catch {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not stage live auth: \(error.localizedDescription)")
        }
    }
}
