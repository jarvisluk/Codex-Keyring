import Foundation
import CodexKeyringDomain

extension LiveCodexAuthInstaller {
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
                self.log.info("backed up live auth")
                return destination
            } catch {
                throw CodexKeyringError.backupFailed(reason: error.localizedDescription)
            }
        }
    }

    func uniqueBackupDestination(stem: String) -> URL {
        var candidate = backupsDirectory.appendingPathComponent("\(stem).json")
        var suffix = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = backupsDirectory.appendingPathComponent("\(stem)-\(suffix).json")
            suffix += 1
        }
        return candidate
    }
}
