import Foundation

public protocol AccountRepository: Sendable {
    func load() async throws -> AccountManifest
    func save(_ manifest: AccountManifest) async throws

    /// Copy the source auth file into the snapshot store under the given
    /// account ID, returning the local snapshot file name.
    func writeSnapshot(from source: URL, for accountID: UUID) async throws -> String

    func deleteSnapshot(named fileName: String) async throws
    func snapshotURL(named fileName: String) -> URL
    func snapshotExists(named fileName: String) -> Bool
}
