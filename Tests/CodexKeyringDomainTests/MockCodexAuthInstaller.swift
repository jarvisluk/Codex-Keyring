import Foundation
@testable import CodexKeyringDomain

final class MockInstaller: CodexAuthInstalling, @unchecked Sendable {
    let liveAuthFileURL: URL
    private let registry: AuthFileRegistry
    private let backupError: Error?
    private let restoreError: Error?
    private let removeStagedError: Error?
    private let lock = NSLock()
    private var nextStage = 0
    private(set) var backupCount = 0
    private(set) var installCount = 0
    private(set) var restoreCount = 0
    private(set) var removeStagedCount = 0

    init(
        liveAuthFileURL: URL,
        registry: AuthFileRegistry,
        backupError: Error? = nil,
        restoreError: Error? = nil,
        removeStagedError: Error? = nil
    ) {
        self.liveAuthFileURL = liveAuthFileURL
        self.registry = registry
        self.backupError = backupError
        self.restoreError = restoreError
        self.removeStagedError = removeStagedError
    }

    func install(snapshot: URL) async throws {
        installCount += 1
        guard let metadata = registry.metadata(for: snapshot) else {
            throw CodexKeyringError.authFileMissing(snapshot)
        }
        registry.set(metadata, for: liveAuthFileURL)
    }

    func backupCurrent() async throws -> URL? {
        if let backupError {
            throw backupError
        }
        guard let metadata = registry.metadata(for: liveAuthFileURL) else {
            return nil
        }
        backupCount += 1
        let url = URL(fileURLWithPath: "/tmp/backup-\(backupCount).json")
        registry.set(metadata, for: url)
        return url
    }

    func stageLiveAuthIfPresent(prefix: String) async throws -> URL? {
        guard registry.metadata(for: liveAuthFileURL) != nil else {
            return nil
        }
        return try await stageRequiredLiveAuth(prefix: prefix)
    }

    func stageRequiredLiveAuth(prefix: String) async throws -> URL {
        guard let metadata = registry.metadata(for: liveAuthFileURL) else {
            throw CodexKeyringError.authFileMissing(liveAuthFileURL)
        }
        let url = lock.withLock { () -> URL in
            nextStage += 1
            return URL(fileURLWithPath: "/tmp/\(prefix)-\(nextStage).json")
        }
        registry.set(metadata, for: url)
        return url
    }

    func restoreLiveAuth(from stagedURL: URL?) async throws {
        restoreCount += 1
        if let restoreError {
            throw restoreError
        }
        guard let stagedURL else {
            registry.remove(liveAuthFileURL)
            return
        }
        try await install(snapshot: stagedURL)
    }

    func removeStagedAuth(_ url: URL?) async throws {
        guard let url else { return }
        removeStagedCount += 1
        if let removeStagedError {
            throw removeStagedError
        }
        registry.remove(url)
    }
}
