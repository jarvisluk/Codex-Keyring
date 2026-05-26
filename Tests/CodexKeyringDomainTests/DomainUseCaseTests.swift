import XCTest
@testable import CodexKeyringDomain

final class DomainUseCaseTests: XCTestCase {
    func testAddAccountCanSaveWithoutActivatingCurrentAccount() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let newURL = URL(fileURLWithPath: "/tmp/new-auth.json")
        let registry = AuthFileRegistry([liveURL: old, newURL: new])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [oldAccount], activeAccountID: oldAccount.id, settings: AppSettings())
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 100))
        )(
            sourceURL: newURL,
            requestedAlias: nil,
            activate: false
        )

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(result.state.activeAccountID, oldAccount.id)
        XCTAssertEqual(saved.accounts.map(\.alias).sorted(), ["new", "old"])
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "old")
    }

    func testSwitchAccountInstallsSnapshotBacksUpAndRestarts() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [oldAccount, newAccount], activeAccountID: oldAccount.id, settings: AppSettings())
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
        let appController = MockAppController(outcome: .relaunched)

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: MockAuthReader(registry: registry),
            appController: appController
        )(accountID: newAccount.id, restartCodexApp: true)

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, newAccount.id)
        XCTAssertEqual(result.restartOutcome, .relaunched)
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "new")
        XCTAssertEqual(installer.backupCount, 1)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "new")
    }

    func testLoginNewAccountRestoresPreviousLiveAuthAndSavesInactiveSnapshot() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [oldAccount], activeAccountID: oldAccount.id, settings: AppSettings())
        )
        let loginService = MockLoginService { urlOpener in
            try await urlOpener(URL(string: "https://example.test/login")!)
            registry.set(new, for: liveURL)
        }

        let recorder = URLRecorder()
        let useCase = LoginNewAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            loginService: loginService,
            clock: FixedClock(Date(timeIntervalSince1970: 100))
        )
        let result = try await useCase.callAsFunction(openAuthURL: { url in
            recorder.url = url
        })

        let saved = try await repository.load()
        XCTAssertEqual(recorder.url?.absoluteString, "https://example.test/login")
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "old")
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(saved.accounts.map(\.alias).sorted(), ["new", "old"])
        XCTAssertEqual(result.state.activeAccountID, oldAccount.id)
        XCTAssertEqual(result.savedAlias, "new")
    }

    func testSyncLiveAuthCapturesRotatedRefreshToken() async throws {
        let identifier = "user-123"
        let original = AuthMetadata(
            email: "user@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fingerprint-v1",
            tokenExpiresAt: nil
        )
        let rotated = AuthMetadata(
            email: "user@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fingerprint-v2",
            tokenExpiresAt: nil
        )
        let saved = account(id: UUID(), alias: "primary", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: rotated])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        let result = try await SyncLiveAuthUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 200))
        )()

        let manifest = try await repository.load()
        XCTAssertTrue(result.didUpdateSnapshot)
        XCTAssertFalse(result.didReassignActive)
        XCTAssertEqual(result.updatedAccountID, saved.id)
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.lastSnapshotWrite?.source, liveURL)
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, saved.id)
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "fingerprint-v2")
        XCTAssertEqual(manifest.activeAccountID, saved.id)
    }

    func testSyncLiveAuthSkipsApiKeyIdentifier() async throws {
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        // Two API-key accounts share the placeholder identifier "api-key";
        // we must not let a fingerprint drift cause cross-account writes.
        let liveAuth = AuthMetadata(
            email: "api@example.com",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: "api-key",
            fingerprint: "live-fp",
            tokenExpiresAt: nil
        )
        let existing = AuthMetadata(
            email: "other@example.com",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: "api-key",
            fingerprint: "different-fp",
            tokenExpiresAt: nil
        )
        let stored = account(id: UUID(), alias: "api", metadata: existing)
        let registry = AuthFileRegistry([liveURL: liveAuth])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [stored], activeAccountID: stored.id, settings: AppSettings())
        )

        let result = try await SyncLiveAuthUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry)
        )()

        XCTAssertEqual(result, .noop)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
    }

    func testSwitchAccountWritesRotatedTokenBackBeforeInstalling() async throws {
        let identifier = "user-A"
        let oldFingerprint = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v1",
            tokenExpiresAt: nil
        )
        let rotated = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v2",
            tokenExpiresAt: nil
        )
        let newMeta = metadata(email: "b@example.com", fingerprint: "fp-B")
        let accountA = account(id: UUID(), alias: "A", metadata: oldFingerprint)
        let accountB = account(id: UUID(), alias: "B", metadata: newMeta)

        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: rotated])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [accountA, accountB], activeAccountID: accountA.id, settings: AppSettings())
        )
        registry.set(newMeta, for: repository.snapshotURL(named: accountB.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
        let appController = MockAppController(outcome: .relaunched)

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: MockAuthReader(registry: registry),
            appController: appController
        )(accountID: accountB.id, restartCodexApp: false)

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1, "Should re-snapshot account A before switching away")
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, accountA.id)
        XCTAssertEqual(repository.lastSnapshotWrite?.source, liveURL)
        XCTAssertEqual(manifest.accounts.first(where: { $0.id == accountA.id })?.fingerprint, "fp-A-v2")
        XCTAssertEqual(manifest.activeAccountID, accountB.id)
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "fp-B")
        XCTAssertEqual(installer.backupCount, 1)
    }

    func testRefreshStateAdoptsRotatedFingerprintForActiveAccount() async throws {
        let identifier = "user-A"
        let original = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v1",
            tokenExpiresAt: nil
        )
        let rotated = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v2",
            tokenExpiresAt: nil
        )
        let accountA = account(id: UUID(), alias: "A", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: rotated])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [accountA], activeAccountID: accountA.id, settings: AppSettings())
        )

        let state = try await RefreshStateUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry)
        )()

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "fp-A-v2")
        XCTAssertEqual(state.activeAccountID, accountA.id)
        XCTAssertEqual(state.currentAuthMetadata?.fingerprint, "fp-A-v2")
        XCTAssertEqual(repository.snapshotWriteCount, 1)
    }

    func testAliasPolicyFallsBackAndUniquifiesCaseInsensitively() {
        let policy = AliasPolicy()

        XCTAssertEqual(policy.clean("  ", fallback: "fallback"), "fallback")
        XCTAssertEqual(
            policy.uniquified("Work", existingAliases: ["work", "work-2"]),
            "Work-3"
        )
        XCTAssertEqual(
            policy.suggested(for: metadata(email: "", fingerprint: "empty")),
            "account"
        )
    }
}

private func metadata(email: String, fingerprint: String) -> AuthMetadata {
    AuthMetadata(
        email: email,
        plan: "plus",
        authMode: "chatgpt",
        accountIdentifier: fingerprint,
        fingerprint: fingerprint,
        tokenExpiresAt: nil
    )
}

private func account(id: UUID, alias: String, metadata: AuthMetadata) -> CodexAccount {
    CodexAccount(
        id: id,
        alias: alias,
        email: metadata.email,
        plan: metadata.plan,
        authMode: metadata.authMode,
        accountIdentifier: metadata.accountIdentifier,
        snapshotFileName: "\(id.uuidString).auth.json",
        fingerprint: metadata.fingerprint,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        tokenExpiresAt: nil
    )
}

private final class AuthFileRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var files: [URL: AuthMetadata]

    init(_ files: [URL: AuthMetadata]) {
        self.files = files
    }

    func metadata(for url: URL) -> AuthMetadata? {
        lock.withLock { files[url] }
    }

    func set(_ metadata: AuthMetadata, for url: URL) {
        lock.withLock { files[url] = metadata }
    }

    func remove(_ url: URL) {
        _ = lock.withLock { files.removeValue(forKey: url) }
    }
}

private final class URLRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedURL: URL?

    var url: URL? {
        get { lock.withLock { recordedURL } }
        set { lock.withLock { recordedURL = newValue } }
    }
}

private final class InMemoryAccountRepository: AccountRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var manifest: AccountManifest
    private let snapshotBaseURL = URL(fileURLWithPath: "/tmp/snapshots", isDirectory: true)
    private(set) var snapshotWriteCount = 0
    private(set) var lastSnapshotWrite: (source: URL, accountID: UUID)?

    init(manifest: AccountManifest) {
        self.manifest = manifest
    }

    func load() async throws -> AccountManifest {
        lock.withLock { manifest }
    }

    func save(_ manifest: AccountManifest) async throws {
        lock.withLock { self.manifest = manifest }
    }

    func writeSnapshot(from source: URL, for accountID: UUID) async throws -> String {
        lock.withLock {
            snapshotWriteCount += 1
            lastSnapshotWrite = (source, accountID)
        }
        return "\(accountID.uuidString).auth.json"
    }

    func deleteSnapshot(named fileName: String) async throws {}

    func snapshotURL(named fileName: String) -> URL {
        snapshotBaseURL.appendingPathComponent(fileName)
    }

    func snapshotExists(named fileName: String) -> Bool {
        true
    }
}

private final class MockAuthReader: AuthFileReading, @unchecked Sendable {
    private let registry: AuthFileRegistry

    init(registry: AuthFileRegistry) {
        self.registry = registry
    }

    func read(from url: URL) async throws -> AuthMetadata {
        guard let metadata = registry.metadata(for: url) else {
            throw CodexKeyringError.authFileMissing(url)
        }
        return metadata
    }
}

private final class MockInstaller: CodexAuthInstalling, @unchecked Sendable {
    let liveAuthFileURL: URL
    private let registry: AuthFileRegistry
    private let lock = NSLock()
    private var nextStage = 0
    private(set) var backupCount = 0

    init(liveAuthFileURL: URL, registry: AuthFileRegistry) {
        self.liveAuthFileURL = liveAuthFileURL
        self.registry = registry
    }

    func install(snapshot: URL) async throws {
        guard let metadata = registry.metadata(for: snapshot) else {
            throw CodexKeyringError.authFileMissing(snapshot)
        }
        registry.set(metadata, for: liveAuthFileURL)
    }

    func backupCurrent() async throws -> URL? {
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
        guard let stagedURL else {
            registry.remove(liveAuthFileURL)
            return
        }
        try await install(snapshot: stagedURL)
    }

    func removeStagedAuth(_ url: URL?) async {
        guard let url else { return }
        registry.remove(url)
    }
}

private final class MockAppController: CodexAppControlling, @unchecked Sendable {
    var isRunning = true
    private let outcome: CodexAppRestartOutcome
    private(set) var restartCallCount = 0

    init(outcome: CodexAppRestartOutcome) {
        self.outcome = outcome
    }

    func restartIfRunning() async throws -> CodexAppRestartOutcome {
        restartCallCount += 1
        return outcome
    }
}

private final class MockLoginService: CodexLoginServicing, @unchecked Sendable {
    private let action: @Sendable (@escaping @Sendable (URL) async throws -> Void) async throws -> Void

    init(action: @escaping @Sendable (@escaping @Sendable (URL) async throws -> Void) async throws -> Void) {
        self.action = action
    }

    func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        try await action(openAuthURL)
    }
}
