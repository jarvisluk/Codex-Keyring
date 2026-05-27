import Foundation
import CodexKeyringDomain

/// `AccountRepository` backed by the local file system under
/// `~/Library/Application Support/CodexKeyring`.
///
/// Blocking IO is performed on a private serial queue so calls from the
/// `@MainActor` store never freeze the UI and manifest mutations do not race
/// each other on disk.
public final class FileSystemManifestRepository: AccountRepository, @unchecked Sendable {
    public let manifestURL: URL
    public let accountsDirectory: URL
    public let applicationSupportDirectory: URL

    private let log = CodexKeyringLog.makeAppLogger(.manifest)
    private let ioQueue: DispatchQueue
    private var fileManager: FileManager { .default }

    public init(
        applicationSupportDirectory: URL = AppPaths.applicationSupportDirectory,
        accountsDirectory: URL = AppPaths.accountsDirectory,
        manifestURL: URL = AppPaths.manifestFile,
        ioQueue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.ManifestRepository")
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.accountsDirectory = accountsDirectory
        self.manifestURL = manifestURL
        self.ioQueue = ioQueue
    }

    public func load() async throws -> AccountManifest {
        try await performIO {
            try self.ensureDirectories()
            guard self.fileManager.fileExists(atPath: self.manifestURL.path) else {
                self.log.info("manifest not found, returning empty")
                return .empty
            }
            let data: Data
            do {
                data = try Data(contentsOf: self.manifestURL)
            } catch {
                self.log.error("failed to read manifest: \(String(describing: error))")
                throw CodexKeyringError.fileSystemFailure(reason: "Could not read profiles.json: \(error.localizedDescription)")
            }
            do {
                let manifest = try Self.decoder.decode(AccountManifest.self, from: data)
                let (normalized, repairedActiveAccountID) = Self.normalized(manifest)
                if repairedActiveAccountID {
                    do {
                        try self.writeManifest(normalized)
                        self.log.info("cleared stale active account id from manifest")
                    } catch {
                        self.log.warning("failed to persist repaired manifest: \(String(describing: error))")
                    }
                }
                return normalized
            } catch {
                self.log.error("failed to decode manifest: \(String(describing: error))")
                throw CodexKeyringError.fileSystemFailure(reason: "Could not read profiles.json: \(error.localizedDescription)")
            }
        }
    }

    public func save(_ manifest: AccountManifest) async throws {
        try await performIO {
            try self.ensureDirectories()
            do {
                let (normalized, _) = Self.normalized(manifest)
                try self.writeManifest(normalized)
                self.log.debug("manifest saved (\(manifest.accounts.count) accounts)")
            } catch {
                self.log.error("failed to write manifest: \(String(describing: error))")
                throw CodexKeyringError.fileSystemFailure(reason: "Could not write profiles.json: \(error.localizedDescription)")
            }
        }
    }

    public func writeSnapshot(from source: URL, for accountID: UUID) async throws -> String {
        try await performIO {
            try self.ensureDirectories()
            let fileName = "\(accountID.uuidString).auth.json"
            let destination = self.accountsDirectory.appendingPathComponent(fileName)
            try self.writeAtomically(from: source, to: destination)
            self.log.debug("snapshot written for \(accountID.uuidString)")
            return fileName
        }
    }

    public func deleteSnapshot(named fileName: String) async throws {
        try await performIO {
            guard let url = self.validSnapshotURL(named: fileName) else {
                throw CodexKeyringError.fileSystemFailure(reason: "Invalid snapshot file name.")
            }
            guard try self.snapshotFileExists(at: url) else { return }
            do {
                try self.fileManager.removeItem(at: url)
                self.log.debug("snapshot deleted \(fileName)")
            } catch {
                throw CodexKeyringError.fileSystemFailure(reason: "Could not delete snapshot: \(error.localizedDescription)")
            }
        }
    }

    public func snapshotURL(named fileName: String) -> URL {
        guard let url = validSnapshotURL(named: fileName) else {
            return accountsDirectory.appendingPathComponent(".invalid-snapshot-name")
        }
        return url
    }

    public func snapshotExists(named fileName: String) -> Bool {
        guard let url = validSnapshotURL(named: fileName) else { return false }
        return (try? snapshotFileExists(at: url)) ?? false
    }

    private func validSnapshotURL(named fileName: String) -> URL? {
        guard Self.isValidSnapshotFileName(fileName) else { return nil }
        return accountsDirectory.appendingPathComponent(fileName)
    }

    private static func isValidSnapshotFileName(_ fileName: String) -> Bool {
        let suffix = ".auth.json"
        guard fileName.hasSuffix(suffix) else { return false }
        guard fileName == (fileName as NSString).lastPathComponent else { return false }
        let idPart = String(fileName.dropLast(suffix.count))
        return UUID(uuidString: idPart) != nil
    }

    // MARK: - Helpers

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

    private func ensureDirectories() throws {
        do {
            try PrivateFilePermissions.createDirectory(at: applicationSupportDirectory, fileManager: fileManager)
            try PrivateFilePermissions.createDirectory(at: accountsDirectory, fileManager: fileManager)
        } catch {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not prepare storage: \(error.localizedDescription)")
        }
    }

    private func writeAtomically(from source: URL, to destination: URL) throws {
        try requireSnapshotSourceFile(at: source)
        let tmp = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            _ = try snapshotFileExists(at: destination)
            try fileManager.copyItem(at: source, to: tmp)
            try setPrivateFilePermissions(at: tmp)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: destination)
            }
            try setPrivateFilePermissions(at: destination)
        } catch {
            try? fileManager.removeItem(at: tmp)
            throw CodexKeyringError.fileSystemFailure(reason: "Could not stage snapshot: \(error.localizedDescription)")
        }
    }

    private func setPrivateFilePermissions(at url: URL) throws {
        try PrivateFilePermissions.setFile(at: url, fileManager: fileManager)
    }

    private func snapshotFileExists(at url: URL) throws -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { return false }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Snapshot path is not a file: \(url.path)"
            )
        }
        return true
    }

    private func requireSnapshotSourceFile(at url: URL) throws {
        var isDirectory = ObjCBool(false)
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else {
            throw CodexKeyringError.authFileMissing(url)
        }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Snapshot source is not a file: \(url.path)"
            )
        }
    }

    private func writeManifest(_ manifest: AccountManifest) throws {
        let data = try Self.encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
        try setPrivateFilePermissions(at: manifestURL)
    }

    private static func normalized(_ manifest: AccountManifest) -> (AccountManifest, repairedActiveAccountID: Bool) {
        var normalized = manifest
        normalized.accounts.sort(by: accountSortPrecedes)

        guard let activeID = normalized.activeAccountID else {
            return (normalized, false)
        }
        let hasActiveAccount = normalized.accounts.contains { $0.id == activeID }
        if hasActiveAccount {
            return (normalized, false)
        }

        normalized.activeAccountID = nil
        return (normalized, true)
    }

    private static func accountSortPrecedes(_ lhs: CodexAccount, _ rhs: CodexAccount) -> Bool {
        CodexAccount.displayOrderPrecedes(lhs, rhs)
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
