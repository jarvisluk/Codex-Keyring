import Foundation
import CodexKeyringDomain

extension FileSystemManifestRepository {
    public func writeSnapshot(from source: URL, for accountID: UUID) async throws -> String {
        try await performIO {
            try self.ensureDirectories()
            let fileName = try self.snapshotStore.writeAtomically(from: source, for: accountID)
            self.log.debug("snapshot written for \(accountID.uuidString)")
            return fileName
        }
    }

    public func deleteSnapshot(named fileName: String) async throws {
        try await performIO {
            try self.snapshotStore.delete(named: fileName)
            self.log.debug("snapshot deleted")
        }
    }

    public func snapshotURL(named fileName: String) -> URL {
        snapshotStore.url(named: fileName)
    }

    public func snapshotExists(named fileName: String) -> Bool {
        snapshotStore.exists(named: fileName)
    }
}
