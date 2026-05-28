import Foundation
import CodexKeyringDomain

extension LiveCodexAuthInstaller {
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

    func stageLiveAuth(prefix: String) throws -> URL {
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
}
