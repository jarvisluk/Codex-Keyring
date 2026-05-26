import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [CodexAccount] = []
    @Published private(set) var activeAccountID: UUID?
    @Published private(set) var currentAuthMetadata: AuthMetadata?
    @Published var settings: AppSettings = AppSettings() {
        didSet {
            saveManifest()
        }
    }
    @Published var statusMessage: String = "Ready."
    @Published var lastError: String?

    init() {
        loadManifest()
        refresh()
        settings.launchAtLogin = LaunchAtLoginController.isEnabled
    }

    var activeAccount: CodexAccount? {
        if let id = activeAccountID,
           let account = accounts.first(where: { $0.id == id }) {
            return account
        }

        if let fingerprint = currentAuthMetadata?.fingerprint {
            return accounts.first(where: { $0.fingerprint == fingerprint })
        }

        return nil
    }

    func refresh() {
        do {
            try AppPaths.ensureDirectories()
            currentAuthMetadata = try? AuthMetadataParser.parseAuthFile(at: AppPaths.codexAuthFile)
            if let fingerprint = currentAuthMetadata?.fingerprint,
               let account = accounts.first(where: { $0.fingerprint == fingerprint }) {
                activeAccountID = account.id
            }
            saveManifest()
        } catch {
            setError(error)
        }
    }

    func addCurrentAccount(alias requestedAlias: String?) {
        do {
            let metadata = try AuthMetadataParser.parseAuthFile(at: AppPaths.codexAuthFile)
            let alias = cleanAlias(requestedAlias, fallback: suggestedAlias(for: metadata))
            try upsertAccount(from: AppPaths.codexAuthFile, metadata: metadata, alias: alias)
            currentAuthMetadata = metadata
            statusMessage = "Saved current Codex auth as \(alias)."
        } catch {
            setError(error)
        }
    }

    func importAccount(from url: URL, alias requestedAlias: String? = nil) {
        do {
            let metadata = try AuthMetadataParser.parseAuthFile(at: url)
            let alias = cleanAlias(requestedAlias, fallback: suggestedAlias(for: metadata))
            try upsertAccount(from: url, metadata: metadata, alias: alias)
            statusMessage = "Imported account \(alias)."
        } catch {
            setError(error)
        }
    }

    func switchTo(_ account: CodexAccount, restartCodexApp: Bool) {
        do {
            try AppPaths.ensureDirectories()
            let snapshotURL = AppPaths.accountsDirectory.appendingPathComponent(account.snapshotFileName)
            guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
                throw AccountStoreError.snapshotMissing
            }

            if currentAuthMetadata?.fingerprint != account.fingerprint {
                try backupCurrentAuthIfPresent()
                try replaceCodexAuth(with: snapshotURL)
            }

            activeAccountID = account.id
            currentAuthMetadata = try? AuthMetadataParser.parseAuthFile(at: AppPaths.codexAuthFile)
            saveManifest()

            if restartCodexApp {
                statusMessage = try CodexAppController.restartCodexAppIfRunning()
            } else {
                statusMessage = "Switched Codex CLI auth to \(account.displayName). Restart Codex App if it was already open."
            }
        } catch {
            setError(error)
        }
    }

    func remove(_ account: CodexAccount) {
        do {
            let snapshotURL = AppPaths.accountsDirectory.appendingPathComponent(account.snapshotFileName)
            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                try FileManager.default.removeItem(at: snapshotURL)
            }
            accounts.removeAll { $0.id == account.id }
            if activeAccountID == account.id {
                activeAccountID = nil
            }
            saveManifest()
            refresh()
            statusMessage = "Removed saved account \(account.displayName). Current Codex auth was left untouched."
        } catch {
            setError(error)
        }
    }

    func rename(_ account: CodexAccount, to newAlias: String) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            return
        }
        accounts[index].alias = cleanAlias(newAlias, fallback: accounts[index].alias)
        accounts[index].updatedAt = Date()
        saveManifest()
        statusMessage = "Renamed account."
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
            settings.launchAtLogin = LaunchAtLoginController.isEnabled
            statusMessage = enabled ? "Launch at login enabled." : "Launch at login disabled."
        } catch {
            settings.launchAtLogin = LaunchAtLoginController.isEnabled
            setError(error)
        }
    }

    func clearError() {
        lastError = nil
    }

    private func loadManifest() {
        do {
            try AppPaths.ensureDirectories()
            guard FileManager.default.fileExists(atPath: AppPaths.manifestFile.path) else {
                accounts = []
                activeAccountID = nil
                settings = AppSettings()
                return
            }
            let data = try Data(contentsOf: AppPaths.manifestFile)
            let manifest = try JSONDecoder.accountSwitcher.decode(AccountManifest.self, from: data)
            accounts = manifest.accounts.sorted { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
            activeAccountID = manifest.activeAccountID
            settings = manifest.settings
        } catch {
            accounts = []
            activeAccountID = nil
            settings = AppSettings()
            setError(error)
        }
    }

    private func saveManifest() {
        do {
            try AppPaths.ensureDirectories()
            let manifest = AccountManifest(accounts: accounts, activeAccountID: activeAccountID, settings: settings)
            let data = try JSONEncoder.accountSwitcher.encode(manifest)
            try data.write(to: AppPaths.manifestFile, options: .atomic)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func upsertAccount(from sourceURL: URL, metadata: AuthMetadata, alias: String) throws {
        try AppPaths.ensureDirectories()
        if let index = accounts.firstIndex(where: { $0.fingerprint == metadata.fingerprint }) {
            let fileName = accounts[index].snapshotFileName
            try copyAuthSnapshot(from: sourceURL, to: AppPaths.accountsDirectory.appendingPathComponent(fileName))
            accounts[index].alias = alias
            accounts[index].email = metadata.email
            accounts[index].plan = metadata.plan
            accounts[index].authMode = metadata.authMode
            accounts[index].accountIdentifier = metadata.accountIdentifier
            accounts[index].updatedAt = Date()
            accounts[index].tokenExpiresAt = metadata.tokenExpiresAt
            activeAccountID = accounts[index].id
        } else {
            let id = UUID()
            let fileName = "\(id.uuidString).auth.json"
            try copyAuthSnapshot(from: sourceURL, to: AppPaths.accountsDirectory.appendingPathComponent(fileName))
            let account = CodexAccount(
                id: id,
                alias: uniqueAlias(alias),
                email: metadata.email,
                plan: metadata.plan,
                authMode: metadata.authMode,
                accountIdentifier: metadata.accountIdentifier,
                snapshotFileName: fileName,
                fingerprint: metadata.fingerprint,
                createdAt: Date(),
                updatedAt: Date(),
                tokenExpiresAt: metadata.tokenExpiresAt
            )
            accounts.append(account)
            accounts.sort { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
            activeAccountID = account.id
        }
        saveManifest()
    }

    private func copyAuthSnapshot(from sourceURL: URL, to destinationURL: URL) throws {
        let temporaryURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).tmp-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        }
    }

    private func backupCurrentAuthIfPresent() throws {
        guard FileManager.default.fileExists(atPath: AppPaths.codexAuthFile.path) else {
            return
        }
        let fileName = "auth-\(DisplayFormatters.fileTimestamp.string(from: Date())).json"
        try FileManager.default.copyItem(
            at: AppPaths.codexAuthFile,
            to: AppPaths.backupsDirectory.appendingPathComponent(fileName)
        )
    }

    private func replaceCodexAuth(with snapshotURL: URL) throws {
        try FileManager.default.createDirectory(at: AppPaths.codexDirectory, withIntermediateDirectories: true)
        let temporaryURL = AppPaths.codexDirectory.appendingPathComponent(".auth.json.codex-switcher-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: snapshotURL, to: temporaryURL)
        if FileManager.default.fileExists(atPath: AppPaths.codexAuthFile.path) {
            _ = try FileManager.default.replaceItemAt(AppPaths.codexAuthFile, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: AppPaths.codexAuthFile)
        }
    }

    private func suggestedAlias(for metadata: AuthMetadata) -> String {
        if metadata.email.contains("@") {
            return metadata.email.components(separatedBy: "@").first ?? metadata.email
        }
        return metadata.email
    }

    private func cleanAlias(_ alias: String?, fallback: String) -> String {
        let cleaned = (alias ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    private func uniqueAlias(_ alias: String) -> String {
        let existing = Set(accounts.map { $0.alias.lowercased() })
        guard existing.contains(alias.lowercased()) else {
            return alias
        }
        var index = 2
        while existing.contains("\(alias)-\(index)".lowercased()) {
            index += 1
        }
        return "\(alias)-\(index)"
    }

    private func setError(_ error: Error) {
        lastError = error.localizedDescription
        statusMessage = error.localizedDescription
    }
}

enum AccountStoreError: LocalizedError {
    case snapshotMissing

    var errorDescription: String? {
        switch self {
        case .snapshotMissing:
            return "The saved auth snapshot is missing."
        }
    }
}

private extension JSONEncoder {
    static var accountSwitcher: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var accountSwitcher: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
