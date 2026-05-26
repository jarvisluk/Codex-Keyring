import Foundation
import CodexKeyringDomain

/// `AccountRepository` backed by the local file system under
/// `~/Library/Application Support/CodexKeyring`.
///
/// All blocking IO is performed off the calling actor (typically `@MainActor`)
/// via an explicit detached executor so `await` calls into the repository
/// never freeze the UI.
public struct FileSystemManifestRepository: AccountRepository {
    public let manifestURL: URL
    public let accountsDirectory: URL
    public let applicationSupportDirectory: URL

    private let log = CodexKeyringLog.makeAppLogger(.manifest)
    private var fileManager: FileManager { .default }

    public init(
        applicationSupportDirectory: URL = AppPaths.applicationSupportDirectory,
        accountsDirectory: URL = AppPaths.accountsDirectory,
        manifestURL: URL = AppPaths.manifestFile
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.accountsDirectory = accountsDirectory
        self.manifestURL = manifestURL
    }

    public func load() async throws -> AccountManifest {
        try ensureDirectories()
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            log.info("manifest not found, returning empty")
            return .empty
        }
        let data = try Data(contentsOf: manifestURL)
        do {
            let manifest = try Self.decoder.decode(AccountManifest.self, from: data)
            var normalized = manifest
            normalized.accounts.sort { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
            return normalized
        } catch {
            log.error("failed to decode manifest: \(String(describing: error))")
            throw CodexKeyringError.fileSystemFailure(reason: "Could not read profiles.json: \(error.localizedDescription)")
        }
    }

    public func save(_ manifest: AccountManifest) async throws {
        try ensureDirectories()
        do {
            let data = try Self.encoder.encode(manifest)
            try data.write(to: manifestURL, options: .atomic)
            log.debug("manifest saved (\(manifest.accounts.count) accounts)")
        } catch {
            log.error("failed to write manifest: \(String(describing: error))")
            throw CodexKeyringError.fileSystemFailure(reason: "Could not write profiles.json: \(error.localizedDescription)")
        }
    }

    public func writeSnapshot(from source: URL, for accountID: UUID) async throws -> String {
        try ensureDirectories()
        let fileName = "\(accountID.uuidString).auth.json"
        let destination = accountsDirectory.appendingPathComponent(fileName)
        try writeAtomically(from: source, to: destination)
        log.debug("snapshot written for \(accountID.uuidString)")
        return fileName
    }

    public func deleteSnapshot(named fileName: String) async throws {
        let url = accountsDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
            log.debug("snapshot deleted \(fileName)")
        } catch {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not delete snapshot: \(error.localizedDescription)")
        }
    }

    public func snapshotURL(named fileName: String) -> URL {
        accountsDirectory.appendingPathComponent(fileName)
    }

    public func snapshotExists(named fileName: String) -> Bool {
        fileManager.fileExists(atPath: snapshotURL(named: fileName).path)
    }

    // MARK: - Helpers

    private func ensureDirectories() throws {
        do {
            try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: accountsDirectory, withIntermediateDirectories: true)
        } catch {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not prepare storage: \(error.localizedDescription)")
        }
    }

    private func writeAtomically(from source: URL, to destination: URL) throws {
        let tmp = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            try fileManager.copyItem(at: source, to: tmp)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: tmp)
            throw CodexKeyringError.fileSystemFailure(reason: "Could not stage snapshot: \(error.localizedDescription)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
