import Foundation
import CodexKeyringDomain

/// `CodexAuthInstalling` that copies/replaces `~/.codex/auth.json` atomically
/// and writes timestamped backups under the configured backups directory.
public final class LiveCodexAuthInstaller: CodexAuthInstalling, @unchecked Sendable {
    public let liveAuthFileURL: URL
    public let codexDirectory: URL
    public let backupsDirectory: URL
    public let loginStagingDirectory: URL

    private let log = CodexKeyringLog.makeAppLogger(.installer)
    private var fileManager: FileManager { .default }
    private let clock: Clock
    private let ioQueue: DispatchQueue

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

    @discardableResult
    public func backupCurrent() async throws -> URL? {
        try await performIO {
            do {
                guard try self.authFileExists(at: self.liveAuthFileURL, role: "Live auth path") else {
                    self.log.debug("no live auth file to back up")
                    return nil
                }
                try self.fileManager.createDirectory(at: self.backupsDirectory, withIntermediateDirectories: true)
                try self.setPrivateDirectoryPermissions(at: self.backupsDirectory)
                let stem = "auth-\(DisplayFormatters.fileTimestamp.string(from: self.clock.now()))"
                let destination = self.uniqueBackupDestination(stem: stem)
                try self.fileManager.copyItem(at: self.liveAuthFileURL, to: destination)
                try self.setPrivateFilePermissions(at: destination)
                self.log.info("backed up live auth to \(destination.lastPathComponent)")
                return destination
            } catch {
                throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
            }
        }
    }

    public func stageLiveAuthIfPresent(prefix: String) async throws -> URL? {
        try await performIO {
            guard try self.authFileExists(at: self.liveAuthFileURL, role: "Live auth path") else {
                return nil
            }
            return try self.stageLiveAuth(prefix: prefix)
        }
    }

    public func stageRequiredLiveAuth(prefix: String) async throws -> URL {
        try await performIO {
            guard try self.authFileExists(at: self.liveAuthFileURL, role: "Live auth path") else {
                throw CodexKeyringError.authFileMissing(self.liveAuthFileURL)
            }
            return try self.stageLiveAuth(prefix: prefix)
        }
    }

    public func restoreLiveAuth(from stagedURL: URL?) async throws {
        if let stagedURL {
            try await install(snapshot: stagedURL)
        } else {
            try await performIO {
                if try self.authFileExists(at: self.liveAuthFileURL, role: "Live auth path") {
                    do {
                        try self.fileManager.removeItem(at: self.liveAuthFileURL)
                    } catch {
                        throw CodexKeyringError.fileSystemFailure(reason: "Could not remove temporary live auth: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    public func removeStagedAuth(_ url: URL?) async throws {
        guard let url else { return }
        try await performIO {
            guard self.fileManager.fileExists(atPath: url.path) else { return }
            try self.fileManager.removeItem(at: url)
        }
    }

    private func stageLiveAuth(prefix: String) throws -> URL {
        do {
            try requireAuthFile(at: liveAuthFileURL, role: "Live auth path")
            try fileManager.createDirectory(at: loginStagingDirectory, withIntermediateDirectories: true)
            try setPrivateDirectoryPermissions(at: loginStagingDirectory)
            let destination = loginStagingDirectory
                .appendingPathComponent("\(prefix)-\(UUID().uuidString).auth.json")
            try fileManager.copyItem(at: liveAuthFileURL, to: destination)
            try setPrivateFilePermissions(at: destination)
            return destination
        } catch {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not stage live auth: \(error.localizedDescription)")
        }
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

    private func setPrivateFilePermissions(at url: URL) throws {
        try PrivateFilePermissions.setFile(at: url, fileManager: fileManager)
    }

    private func setPrivateDirectoryPermissions(at url: URL) throws {
        try PrivateFilePermissions.setDirectory(at: url, fileManager: fileManager)
    }

    private func requireAuthFile(at url: URL, role: String) throws {
        guard try authFileExists(at: url, role: role) else {
            throw CodexKeyringError.authFileMissing(url)
        }
    }

    private func authFileExists(at url: URL, role: String) throws -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { return false }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "\(role) is not a file: \(url.path)"
            )
        }
        return true
    }

    private func uniqueBackupDestination(stem: String) -> URL {
        var candidate = backupsDirectory.appendingPathComponent("\(stem).json")
        var suffix = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = backupsDirectory.appendingPathComponent("\(stem)-\(suffix).json")
            suffix += 1
        }
        return candidate
    }
}
