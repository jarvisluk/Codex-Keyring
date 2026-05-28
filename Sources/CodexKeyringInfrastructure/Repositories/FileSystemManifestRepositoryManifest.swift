import Foundation
import CodexKeyringDomain

extension FileSystemManifestRepository {
    public func load() async throws -> AccountManifest {
        try await performIO {
            try self.ensureDirectories()
            guard self.fileManager.fileExists(atPath: self.manifestURL.path) else {
                self.log.info("manifest not found, returning empty")
                return .empty
            }

            let data = try self.readManifestData()
            do {
                let manifest = try Self.decoder.decode(AccountManifest.self, from: data)
                let (normalized, repairedActiveAccountID) = Self.normalized(manifest)
                if repairedActiveAccountID {
                    self.persistRepairedManifestIfPossible(normalized)
                }
                return normalized
            } catch {
                self.log.error("failed to decode manifest: \(String(describing: error))")
                throw CodexKeyringError.fileSystemFailure(
                    reason: "Could not read profiles.json: \(error.localizedDescription)"
                )
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
                throw CodexKeyringError.fileSystemFailure(
                    reason: "Could not write profiles.json: \(error.localizedDescription)"
                )
            }
        }
    }

    func readManifestData() throws -> Data {
        do {
            return try Data(contentsOf: manifestURL)
        } catch {
            log.error("failed to read manifest: \(String(describing: error))")
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not read profiles.json: \(error.localizedDescription)"
            )
        }
    }

    func persistRepairedManifestIfPossible(_ manifest: AccountManifest) {
        do {
            try writeManifest(manifest)
            log.info("cleared stale active account id from manifest")
        } catch {
            log.warning("failed to persist repaired manifest: \(String(describing: error))")
        }
    }

    func writeManifest(_ manifest: AccountManifest) throws {
        let data = try Self.encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
        try PrivateFilePermissions.setFile(at: manifestURL, fileManager: fileManager)
    }
}
