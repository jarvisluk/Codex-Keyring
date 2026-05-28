import Foundation
import CodexKeyringDomain

extension LiveCodexAuthInstaller {
    func performIO<T: Sendable>(
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

    func setPrivateFilePermissions(at url: URL) throws {
        try PrivateFilePermissions.setFile(at: url, fileManager: fileManager)
    }

    func setPrivateDirectoryPermissions(at url: URL) throws {
        try PrivateFilePermissions.setDirectory(at: url, fileManager: fileManager)
    }

    func requireAuthFile(at url: URL, role: String) throws {
        guard try authFileExists(at: url, role: role) else {
            throw CodexKeyringError.authFileMissing(url)
        }
    }

    func authFileExists(at url: URL, role: String) throws -> Bool {
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
}
