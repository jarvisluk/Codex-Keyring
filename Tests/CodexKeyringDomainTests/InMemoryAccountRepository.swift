import Foundation
@testable import CodexKeyringDomain

final class InMemoryAccountRepository: AccountRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var manifest: AccountManifest
    private let snapshotBaseURL = URL(fileURLWithPath: "/tmp/snapshots", isDirectory: true)
    private let saveError: Error?
    private let saveErrorsByAttempt: [Int: Error]
    private let writeError: Error?
    private let deleteError: Error?
    private let snapshotExistsValue: Bool
    private(set) var saveAttempts = 0
    private(set) var saveCount = 0
    private(set) var snapshotWriteCount = 0
    private(set) var lastSnapshotWrite: (source: URL, accountID: UUID)?
    private(set) var deletedSnapshots: [String] = []

    init(
        manifest: AccountManifest,
        saveError: Error? = nil,
        writeError: Error? = nil,
        deleteError: Error? = nil,
        snapshotExists: Bool = true,
        saveErrorsByAttempt: [Int: Error] = [:]
    ) {
        self.manifest = manifest
        self.saveError = saveError
        self.saveErrorsByAttempt = saveErrorsByAttempt
        self.writeError = writeError
        self.deleteError = deleteError
        self.snapshotExistsValue = snapshotExists
    }

    func load() async throws -> AccountManifest {
        lock.withLock { manifest }
    }

    func save(_ manifest: AccountManifest) async throws {
        let attemptError = lock.withLock { () -> Error? in
            saveAttempts += 1
            return saveErrorsByAttempt[saveAttempts]
        }
        if let attemptError {
            throw attemptError
        }
        if let saveError {
            throw saveError
        }
        lock.withLock {
            saveCount += 1
            self.manifest = manifest
        }
    }

    func writeSnapshot(from source: URL, for accountID: UUID) async throws -> String {
        lock.withLock {
            snapshotWriteCount += 1
            lastSnapshotWrite = (source, accountID)
        }
        if let writeError {
            throw writeError
        }
        return "\(accountID.uuidString).auth.json"
    }

    func deleteSnapshot(named fileName: String) async throws {
        if let deleteError {
            throw deleteError
        }
        lock.withLock {
            deletedSnapshots.append(fileName)
        }
    }

    func snapshotURL(named fileName: String) -> URL {
        snapshotBaseURL.appendingPathComponent(fileName)
    }

    func snapshotExists(named fileName: String) -> Bool {
        snapshotExistsValue
    }
}
