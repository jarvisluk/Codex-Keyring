import Foundation
import CodexKeyringDomain

extension FileSystemManifestRepository {
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

    func ensureDirectories() throws {
        do {
            try PrivateFilePermissions.createDirectory(at: applicationSupportDirectory, fileManager: fileManager)
            try PrivateFilePermissions.createDirectory(at: accountsDirectory, fileManager: fileManager)
        } catch {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not prepare storage: \(error.localizedDescription)"
            )
        }
    }

    static func normalized(_ manifest: AccountManifest) -> (
        AccountManifest,
        repairedActiveAccountID: Bool,
        migratedSettingsDefaults: Bool
    ) {
        var normalized = manifest
        normalized.accounts.sort(by: accountSortPrecedes)
        let settingsMigration = normalized.settings.migratedToCurrentDefaults()
        normalized.settings = settingsMigration.settings

        guard let activeID = normalized.activeAccountID else {
            return (normalized, false, settingsMigration.didMigrate)
        }
        let hasActiveAccount = normalized.accounts.contains { $0.id == activeID }
        if hasActiveAccount {
            return (normalized, false, settingsMigration.didMigrate)
        }

        normalized.activeAccountID = nil
        return (normalized, true, settingsMigration.didMigrate)
    }

    static func accountSortPrecedes(_ lhs: CodexAccount, _ rhs: CodexAccount) -> Bool {
        CodexAccount.displayOrderPrecedes(lhs, rhs)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
