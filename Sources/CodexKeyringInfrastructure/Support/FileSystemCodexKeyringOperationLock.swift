import CodexKeyringDomain
import Darwin
import Foundation

public final class FileSystemCodexKeyringOperationLock: CodexKeyringOperationLocking, @unchecked Sendable {
    private let lockFileURL: URL

    public init(lockFileURL: URL = AppPaths.operationLockFile) {
        self.lockFileURL = lockFileURL
    }

    public func withLock<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        let handle = try await acquireLock()
        defer { handle.release() }
        return try await operation()
    }

    private func acquireLock() async throws -> FileSystemCodexKeyringOperationLockHandle {
        let path = lockFileURL.path
        let directory = lockFileURL.deletingLastPathComponent()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try PrivateFilePermissions.createDirectory(at: directory)
                    let fileDescriptor = open(path, O_CREAT | O_RDWR, mode_t(0o600))
                    guard fileDescriptor >= 0 else {
                        throw Self.posixError(operation: "open", errnoValue: errno)
                    }

                    guard flock(fileDescriptor, LOCK_EX) == 0 else {
                        let capturedErrno = errno
                        close(fileDescriptor)
                        throw Self.posixError(operation: "flock", errnoValue: capturedErrno)
                    }

                    continuation.resume(
                        returning: FileSystemCodexKeyringOperationLockHandle(
                            fileDescriptor: fileDescriptor
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func posixError(operation: String, errnoValue: Int32) -> CodexKeyringError {
        let message = String(cString: strerror(errnoValue))
        return .fileSystemFailure(reason: "Could not \(operation) operation lock: \(message)")
    }
}

private final class FileSystemCodexKeyringOperationLockHandle: @unchecked Sendable {
    private let fileDescriptor: Int32
    private let releaseLock = NSLock()
    private var released = false

    init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    func release() {
        releaseLock.lock()
        defer { releaseLock.unlock() }
        guard !released else { return }
        released = true
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }

    deinit {
        release()
    }
}
