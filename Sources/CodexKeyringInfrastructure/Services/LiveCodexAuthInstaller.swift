import Foundation
import os
import CodexKeyringDomain

/// `CodexAuthInstalling` that copies/replaces `~/.codex/auth.json` atomically
/// and writes timestamped backups under the configured backups directory.
public struct LiveCodexAuthInstaller: CodexAuthInstalling {
    public let liveAuthFileURL: URL
    public let codexDirectory: URL
    public let backupsDirectory: URL

    private let log = CodexKeyringLog.make(.installer)
    private var fileManager: FileManager { .default }
    private let clock: Clock

    public init(
        liveAuthFileURL: URL = AppPaths.codexAuthFile,
        codexDirectory: URL = AppPaths.codexDirectory,
        backupsDirectory: URL = AppPaths.backupsDirectory,
        clock: Clock = SystemClock()
    ) {
        self.liveAuthFileURL = liveAuthFileURL
        self.codexDirectory = codexDirectory
        self.backupsDirectory = backupsDirectory
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
            log.info("installed snapshot \(snapshot.lastPathComponent, privacy: .public)")
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
            log.info("backed up live auth to \(fileName, privacy: .public)")
            return destination
        } catch {
            throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
        }
    }
}
