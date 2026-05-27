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

    func testAddAccountUpdatePreservesAliasWhenNoAliasIsRequested() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "same")
        let updated = metadata(email: "new@example.com", fingerprint: "same")
        let saved = account(id: UUID(), alias: "my custom name", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(
            sourceURL: importURL,
            requestedAlias: nil,
            activate: true
        )

        let manifest = try await repository.load()
        let account = try XCTUnwrap(manifest.accounts.first)
        XCTAssertTrue(result.wasUpdate)
        XCTAssertEqual(result.savedAlias, "my custom name")
        XCTAssertEqual(account.alias, "my custom name")
        XCTAssertEqual(account.email, "new@example.com")
        XCTAssertEqual(account.updatedAt, Date(timeIntervalSince1970: 500))
    }

    func testAddAccountUpdateUniquifiesAliasAgainstOtherAccounts() async throws {
        let original = metadata(email: "work@example.com", fingerprint: "work")
        let updated = metadata(email: "updated@example.com", fingerprint: "work")
        let other = metadata(email: "personal@example.com", fingerprint: "personal")
        let accountA = account(id: UUID(), alias: "work", metadata: original)
        let accountB = account(id: UUID(), alias: "personal", metadata: other)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [accountA, accountB], activeAccountID: accountA.id, settings: AppSettings())
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(
            sourceURL: importURL,
            requestedAlias: " personal ",
            activate: true
        )

        let manifest = try await repository.load()
        let renamed = try XCTUnwrap(manifest.accounts.first { $0.id == accountA.id })
        let untouched = try XCTUnwrap(manifest.accounts.first { $0.id == accountB.id })
        XCTAssertTrue(result.wasUpdate)
        XCTAssertEqual(result.savedAlias, "personal-2")
        XCTAssertEqual(renamed.alias, "personal-2")
        XCTAssertEqual(renamed.email, "updated@example.com")
        XCTAssertEqual(untouched.alias, "personal")
        XCTAssertEqual(manifest.accounts.map(\.alias), ["personal", "personal-2"])
    }

    func testAddAccountUpdateDoesNotOverwriteUsefulMetadataWithPlaceholders() async throws {
        let original = AuthMetadata(
            email: "known@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 100)
        )
        let sparse = AuthMetadata(
            email: "Unknown account",
            plan: "chatgpt",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: nil
        )
        let saved = account(id: UUID(), alias: "known", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: sparse])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(
            sourceURL: importURL,
            requestedAlias: nil,
            activate: true
        )

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertTrue(result.wasUpdate)
        XCTAssertEqual(updated.email, "known@example.com")
        XCTAssertEqual(updated.plan, "plus")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 500))
    }

    func testAddAccountUpdateMatchesStableIdentifierWhenFingerprintRotates() async throws {
        let original = AuthMetadata(
            email: "person@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "old-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 100)
        )
        let rotated = AuthMetadata(
            email: "person@example.com",
            plan: "pro",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "new-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 200)
        )
        let existingID = UUID()
        let saved = account(id: existingID, alias: "person", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: rotated])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(
            sourceURL: importURL,
            requestedAlias: nil,
            activate: true
        )

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertTrue(result.wasUpdate)
        XCTAssertEqual(manifest.accounts.count, 1)
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, existingID)
        XCTAssertEqual(updated.id, existingID)
        XCTAssertEqual(updated.alias, "person")
        XCTAssertEqual(updated.plan, "pro")
        XCTAssertEqual(updated.fingerprint, "new-fingerprint")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 200))
    }

    func testAddAccountUpdateDoesNotOverwriteSnapshotWhenManifestSaveFails() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "same")
        let updated = metadata(email: "new@example.com", fingerprint: "same")
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings()),
            saveError: saveError
        )

        do {
            _ = try await AddAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry),
                clock: FixedClock(Date(timeIntervalSince1970: 500))
            )(
                sourceURL: importURL,
                requestedAlias: nil,
                activate: true
            )
            XCTFail("Expected update to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 0)
        XCTAssertEqual(manifest.accounts.first?.email, "old@example.com")
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "same")
    }

    func testAddAccountUpdateRollsBackManifestWhenSnapshotWriteFails() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "same")
        let updated = metadata(email: "new@example.com", fingerprint: "same")
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let writeError = CodexKeyringError.fileSystemFailure(reason: "source vanished")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings()),
            writeError: writeError
        )

        do {
            _ = try await AddAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry),
                clock: FixedClock(Date(timeIntervalSince1970: 500))
            )(
                sourceURL: importURL,
                requestedAlias: nil,
                activate: true
            )
            XCTFail("Expected update to fail when snapshot write fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, writeError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.saveCount, 2)
        XCTAssertEqual(manifest.accounts.first?.email, "old@example.com")
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "same")
    }

    func testAddAccountUpdateReportsWhenManifestRollbackFailsAfterSnapshotWriteFails() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "same")
        let updated = metadata(email: "new@example.com", fingerprint: "same")
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: updated])
        let writeError = CodexKeyringError.fileSystemFailure(reason: "source vanished")
        let rollbackError = CodexKeyringError.fileSystemFailure(reason: "rollback disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings()),
            writeError: writeError,
            saveErrorsByAttempt: [2: rollbackError]
        )

        do {
            _ = try await AddAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry),
                clock: FixedClock(Date(timeIntervalSince1970: 500))
            )(
                sourceURL: importURL,
                requestedAlias: nil,
                activate: true
            )
            XCTFail("Expected update to fail when snapshot write and rollback both fail.")
        } catch CodexKeyringError.manifestRollbackFailed(let originalReason, let rollbackReason) {
            XCTAssertTrue(originalReason.contains("source vanished"))
            XCTAssertTrue(rollbackReason.contains("rollback disk full"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(manifest.accounts.first?.email, "new@example.com")
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "same")
    }

    func testAddAccountDoesNotMatchApiKeyPlaceholderIdentifierAcrossFingerprints() async throws {
        let first = AuthMetadata(
            email: "API key account",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: "api-key",
            fingerprint: "first-key",
            tokenExpiresAt: nil
        )
        let second = AuthMetadata(
            email: "API key account",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: " API-Key ",
            fingerprint: "second-key",
            tokenExpiresAt: nil
        )
        let saved = account(id: UUID(), alias: "first-api", metadata: first)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: second])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(
            sourceURL: importURL,
            requestedAlias: "second-api",
            activate: true
        )

        let manifest = try await repository.load()
        XCTAssertFalse(result.wasUpdate)
        XCTAssertEqual(manifest.accounts.count, 2)
        XCTAssertEqual(manifest.accounts.map(\.alias), ["first-api", "second-api"])
        XCTAssertEqual(Set(manifest.accounts.map(\.fingerprint)), ["first-key", "second-key"])
    }

    func testAddCurrentAccountCapturesAgentPreferencesWhenEnabled() async throws {
        let live = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: live])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(preserveAgentPreferencesPerAccount: true)
            )
        )
        let port = MockAgentPreferencesPort(
            captureValues: [AccountAgentPreferences(model: "gpt-5", agentMode: "full-access")]
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            preferencesPort: port,
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(
            sourceURL: liveURL,
            requestedAlias: "new",
            activate: true
        )

        let saved = try await repository.load()
        let account = try XCTUnwrap(saved.accounts.first)
        XCTAssertEqual(port.captureCallCount, 1)
        XCTAssertEqual(account.agentPreferences?.model, "gpt-5")
        XCTAssertEqual(account.agentPreferences?.agentMode, "full-access")
        XCTAssertNil(result.agentPreferencesWarningReason)
    }

    func testAddCurrentAccountDoesNotCaptureAgentPreferencesWhenDisabled() async throws {
        let live = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: live])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(preserveAgentPreferencesPerAccount: false)
            )
        )
        let port = MockAgentPreferencesPort(
            captureValues: [AccountAgentPreferences(model: "gpt-5")]
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            preferencesPort: port
        )(
            sourceURL: liveURL,
            requestedAlias: "new",
            activate: true
        )

        let saved = try await repository.load()
        let account = try XCTUnwrap(saved.accounts.first)
        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertNil(account.agentPreferences)
        XCTAssertNil(result.agentPreferencesWarningReason)
    }

    func testAddCurrentAccountWarnsWhenAgentPreferenceCaptureFails() async throws {
        let live = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: live])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(preserveAgentPreferencesPerAccount: true)
            )
        )
        let port = MockAgentPreferencesPort(
            captureError: CodexKeyringError.fileSystemFailure(reason: "permission denied")
        )

        let result = try await AddAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            preferencesPort: port
        )(
            sourceURL: liveURL,
            requestedAlias: "new",
            activate: true
        )

        let saved = try await repository.load()
        let account = try XCTUnwrap(saved.accounts.first)
        XCTAssertEqual(saved.activeAccountID, account.id)
        XCTAssertEqual(port.captureCallCount, 1)
        XCTAssertNil(account.agentPreferences)
        XCTAssertTrue(result.agentPreferencesWarningReason?.contains("permission denied") == true)
    }

    func testAddAccountDeletesNewSnapshotWhenManifestSaveFails() async throws {
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: new])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [], activeAccountID: nil, settings: AppSettings()),
            saveError: saveError
        )

        do {
            _ = try await AddAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry),
                clock: FixedClock(Date(timeIntervalSince1970: 500))
            )(
                sourceURL: importURL,
                requestedAlias: "new",
                activate: true
            )
            XCTFail("Expected add account to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let writtenID = try XCTUnwrap(repository.lastSnapshotWrite?.accountID)
        XCTAssertEqual(repository.deletedSnapshots, ["\(writtenID.uuidString).auth.json"])
        let manifest = try await repository.load()
        XCTAssertTrue(manifest.accounts.isEmpty)
    }

    func testAddAccountCleansWrittenSnapshotWhenExistenceCheckCannotConfirmIt() async throws {
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: new])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [], activeAccountID: nil, settings: AppSettings()),
            saveError: saveError,
            snapshotExists: false
        )

        do {
            _ = try await AddAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry),
                clock: FixedClock(Date(timeIntervalSince1970: 500))
            )(
                sourceURL: importURL,
                requestedAlias: "new",
                activate: true
            )
            XCTFail("Expected add account to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let writtenID = try XCTUnwrap(repository.lastSnapshotWrite?.accountID)
        XCTAssertEqual(repository.deletedSnapshots, ["\(writtenID.uuidString).auth.json"])
    }

    func testAddAccountReportsWhenNewSnapshotCleanupFailsAfterManifestSaveFails() async throws {
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let importURL = URL(fileURLWithPath: "/tmp/import-auth.json")
        let registry = AuthFileRegistry([importURL: new])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let deleteError = CodexKeyringError.fileSystemFailure(reason: "delete denied")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [], activeAccountID: nil, settings: AppSettings()),
            saveError: saveError,
            deleteError: deleteError
        )

        do {
            _ = try await AddAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry),
                clock: FixedClock(Date(timeIntervalSince1970: 500))
            )(
                sourceURL: importURL,
                requestedAlias: "new",
                activate: true
            )
            XCTFail("Expected add account to report snapshot cleanup failure.")
        } catch CodexKeyringError.snapshotCleanupFailed(let originalReason, let cleanupReason, let snapshotFileName) {
            XCTAssertTrue(originalReason.contains("disk full"))
            XCTAssertTrue(cleanupReason.contains("delete denied"))
            XCTAssertEqual(snapshotFileName, "\(try XCTUnwrap(repository.lastSnapshotWrite?.accountID).uuidString).auth.json")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertTrue(manifest.accounts.isEmpty)
        XCTAssertTrue(repository.deletedSnapshots.isEmpty)
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

    func testSwitchAccountReturnsSwitchedStateWhenCodexAppRestartFails() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            )
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
        let appController = MockAppController(
            outcome: .relaunched,
            restartError: CodexKeyringError.codexAppRelaunchFailed(reason: "launch denied")
        )

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: MockAuthReader(registry: registry),
            appController: appController
        )(accountID: newAccount.id, restartCodexApp: true)

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, newAccount.id)
        XCTAssertEqual(result.state.activeAccountID, newAccount.id)
        XCTAssertNil(result.restartOutcome)
        XCTAssertEqual(result.restartFailureReason, "launch denied")
        XCTAssertEqual(installer.backupCount, 1)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "new")
    }

    func testSwitchAccountPreservesInstallerBackupFailureReason() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            )
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(
            liveAuthFileURL: liveURL,
            registry: registry,
            backupError: CodexKeyringError.backupFailed(reason: "Live auth path is not a file")
        )

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: MockAuthReader(registry: registry),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: false)
            XCTFail("Expected switch to fail when backup fails.")
        } catch CodexKeyringError.backupFailed(let reason) {
            XCTAssertEqual(reason, "Live auth path is not a file")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "old")
    }

    func testSwitchAccountValidatesSnapshotBeforeBackupOrInstall() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            )
        )
        let snapshotURL = repository.snapshotURL(named: newAccount.snapshotFileName)
        registry.set(new, for: snapshotURL)
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: URLFailingAuthReader(
                    registry: registry,
                    failingURL: snapshotURL,
                    error: CodexKeyringError.authFileUnreadable
                ),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: true)
            XCTFail("Expected switch to fail before installing an unreadable snapshot.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "old")
        XCTAssertEqual(installer.backupCount, 0)
        XCTAssertEqual(installer.installCount, 0)
    }

    func testSwitchAccountReportsMissingSnapshotWhenSnapshotReadIsMissing() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            )
        )
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: MockAuthReader(registry: registry),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: true)
            XCTFail("Expected switch to fail when the snapshot is missing.")
        } catch CodexKeyringError.snapshotMissing(let accountID) {
            XCTAssertEqual(accountID, newAccount.id)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(installer.backupCount, 0)
        XCTAssertEqual(installer.installCount, 0)
        XCTAssertEqual(repository.saveCount, 0)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
    }

    func testSwitchAccountValidatesSnapshotBeforeSyncingRotatedLiveAuth() async throws {
        let stableIdentifier = "old-account"
        let oldStored = AuthMetadata(
            email: "old@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: stableIdentifier,
            fingerprint: "old-stale",
            tokenExpiresAt: nil
        )
        let oldLive = AuthMetadata(
            email: "old@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: stableIdentifier,
            fingerprint: "old-rotated",
            tokenExpiresAt: nil
        )
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldStored)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldLive])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            )
        )
        let snapshotURL = repository.snapshotURL(named: newAccount.snapshotFileName)
        registry.set(new, for: snapshotURL)
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: URLFailingAuthReader(
                    registry: registry,
                    failingURL: snapshotURL,
                    error: CodexKeyringError.authFileUnreadable
                ),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: true)
            XCTFail("Expected switch to fail before syncing live auth.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await repository.load()
        XCTAssertEqual(saved.accounts.first { $0.id == oldAccount.id }?.fingerprint, "old-stale")
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(installer.backupCount, 0)
        XCTAssertEqual(installer.installCount, 0)
        XCTAssertEqual(repository.saveCount, 0)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
    }

    func testSwitchAccountFailsWhenLiveAuthIsUnreadableBeforeBackupOrInstall() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            )
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: URLFailingAuthReader(
                    registry: registry,
                    failingURL: liveURL,
                    error: CodexKeyringError.authFileUnreadable
                ),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: true)
            XCTFail("Expected switch to fail before overwriting an unreadable live auth.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "old")
        XCTAssertEqual(installer.backupCount, 0)
        XCTAssertEqual(installer.installCount, 0)
    }

    func testSwitchAccountRestoresPreviousLiveAuthWhenManifestSaveFails() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            ),
            saveError: saveError
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: MockAuthReader(registry: registry),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: false)
            XCTFail("Expected switch to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "old")
        XCTAssertEqual(installer.backupCount, 1)
        XCTAssertEqual(installer.restoreCount, 1)
    }

    func testSwitchAccountReportsWhenPreviousAuthRestoreFailsAfterManifestSaveFails() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let restoreError = CodexKeyringError.fileSystemFailure(reason: "restore denied")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            ),
            saveError: saveError
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(
            liveAuthFileURL: liveURL,
            registry: registry,
            restoreError: restoreError
        )

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: MockAuthReader(registry: registry),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: false)
            XCTFail("Expected switch to fail when manifest save and live auth restore both fail.")
        } catch CodexKeyringError.previousAuthRestoreFailed(let reason, let recoveryPath) {
            XCTAssertTrue(reason.contains(saveError.localizedDescription))
            XCTAssertTrue(reason.contains(restoreError.localizedDescription))
            XCTAssertEqual(recoveryPath, "/tmp/backup-1.json")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "new")
        XCTAssertEqual(registry.metadata(for: URL(fileURLWithPath: "/tmp/backup-1.json"))?.fingerprint, "old")
        XCTAssertEqual(installer.backupCount, 1)
        XCTAssertEqual(installer.restoreCount, 1)
    }

    func testSwitchAccountRemovesLiveAuthOnSaveFailureWhenNoPreviousAuthExisted() async throws {
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let newAccount = account(id: UUID(), alias: "new", metadata: new)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([:])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [newAccount],
                activeAccountID: nil,
                settings: AppSettings()
            ),
            saveError: saveError
        )
        registry.set(new, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: MockAuthReader(registry: registry),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: newAccount.id, restartCodexApp: false)
            XCTFail("Expected switch to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let saved = try await repository.load()
        XCTAssertNil(saved.activeAccountID)
        XCTAssertNil(registry.metadata(for: liveURL))
        XCTAssertEqual(installer.backupCount, 0)
        XCTAssertEqual(installer.restoreCount, 1)
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
            try await urlOpener(exampleLoginURL())
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

    func testLoginNewAccountReturnsCleanupWarningWhenStageRemovalFailsAfterSuccess() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [oldAccount], activeAccountID: oldAccount.id, settings: AppSettings())
        )
        let cleanupError = CodexKeyringError.fileSystemFailure(reason: "cleanup denied")
        let installer = MockInstaller(
            liveAuthFileURL: liveURL,
            registry: registry,
            removeStagedError: cleanupError
        )
        let loginService = MockLoginService { urlOpener in
            try await urlOpener(exampleLoginURL())
            registry.set(new, for: liveURL)
        }

        let result = try await LoginNewAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: MockAuthReader(registry: registry),
            loginService: loginService,
            clock: FixedClock(Date(timeIntervalSince1970: 100))
        ).callAsFunction(openAuthURL: { _ in })

        let preLoginStage = URL(fileURLWithPath: "/tmp/pre-login-1.json")
        let newLoginStage = URL(fileURLWithPath: "/tmp/new-login-2.json")
        let saved = try await repository.load()
        XCTAssertEqual(saved.accounts.map(\.alias).sorted(), ["new", "old"])
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "old")
        XCTAssertEqual(registry.metadata(for: preLoginStage)?.fingerprint, "old")
        XCTAssertEqual(registry.metadata(for: newLoginStage)?.fingerprint, "new")
        XCTAssertEqual(installer.removeStagedCount, 2)
        XCTAssertTrue(result.cleanupWarningReason?.contains("/tmp/pre-login-1.json") == true)
        XCTAssertTrue(result.cleanupWarningReason?.contains("/tmp/new-login-2.json") == true)
        XCTAssertTrue(result.cleanupWarningReason?.contains("cleanup denied") == true)
    }

    func testLoginNewAccountKeepsPreviousAuthStageWhenRestoreFails() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [oldAccount], activeAccountID: oldAccount.id, settings: AppSettings())
        )
        let installer = MockInstaller(
            liveAuthFileURL: liveURL,
            registry: registry,
            restoreError: CodexKeyringError.fileSystemFailure(reason: "restore failed")
        )
        let loginService = MockLoginService { urlOpener in
            try await urlOpener(exampleLoginURL())
            registry.set(new, for: liveURL)
        }

        do {
            _ = try await LoginNewAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: MockAuthReader(registry: registry),
                loginService: loginService,
                clock: FixedClock(Date(timeIntervalSince1970: 100))
            ).callAsFunction(openAuthURL: { _ in })
            XCTFail("Expected login flow to fail when previous live auth cannot be restored.")
        } catch CodexKeyringError.previousAuthRestoreFailed(let reason, let recoveryPath) {
            XCTAssertTrue(reason.contains("restore failed"))
            XCTAssertEqual(recoveryPath, "/tmp/pre-login-1.json")
            XCTAssertTrue(
                CodexKeyringError.previousAuthRestoreFailed(
                    reason: reason,
                    recoveryPath: recoveryPath
                ).localizedDescription.contains("A recovery copy was kept at /tmp/pre-login-1.json")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let preLoginStage = URL(fileURLWithPath: "/tmp/pre-login-1.json")
        let newLoginStage = URL(fileURLWithPath: "/tmp/new-login-2.json")
        let saved = try await repository.load()
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "new")
        XCTAssertEqual(registry.metadata(for: preLoginStage)?.fingerprint, "old")
        XCTAssertNil(registry.metadata(for: newLoginStage))
        XCTAssertEqual(saved.accounts.map(\.alias), ["old"])
        XCTAssertEqual(installer.restoreCount, 2)
    }

    func testLoginNewAccountCleansStagesWhenSaveFailsAfterRestoreSucceeds() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: old])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [oldAccount], activeAccountID: oldAccount.id, settings: AppSettings()),
            saveError: saveError
        )
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
        let loginService = MockLoginService { urlOpener in
            try await urlOpener(exampleLoginURL())
            registry.set(new, for: liveURL)
        }

        do {
            _ = try await LoginNewAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: MockAuthReader(registry: registry),
                loginService: loginService,
                clock: FixedClock(Date(timeIntervalSince1970: 100))
            ).callAsFunction(openAuthURL: { _ in })
            XCTFail("Expected login flow to fail when saving the new account fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let preLoginStage = URL(fileURLWithPath: "/tmp/pre-login-1.json")
        let newLoginStage = URL(fileURLWithPath: "/tmp/new-login-2.json")
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "old")
        XCTAssertNil(registry.metadata(for: preLoginStage))
        XCTAssertNil(registry.metadata(for: newLoginStage))
        XCTAssertEqual(installer.restoreCount, 1)
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
        XCTAssertTrue(result.didUpdateMetadata)
        XCTAssertFalse(result.didReassignActive)
        XCTAssertEqual(result.updatedAccountID, saved.id)
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.lastSnapshotWrite?.source, liveURL)
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, saved.id)
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "fingerprint-v2")
        XCTAssertEqual(manifest.activeAccountID, saved.id)
    }

    func testSyncLiveAuthRefreshesMetadataWhenFingerprintIsUnchanged() async throws {
        let original = AuthMetadata(
            email: "old@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: nil
        )
        let refreshed = AuthMetadata(
            email: "new@example.com",
            plan: "business",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 300)
        )
        let saved = account(id: UUID(), alias: "primary", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: refreshed])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        let result = try await SyncLiveAuthUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 400))
        )()

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertFalse(result.didUpdateSnapshot)
        XCTAssertTrue(result.didUpdateMetadata)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
        XCTAssertEqual(updated.email, "new@example.com")
        XCTAssertEqual(updated.plan, "business")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 400))
    }

    func testSyncLiveAuthDoesNotOverwriteUsefulMetadataWithPlaceholders() async throws {
        let original = AuthMetadata(
            email: "known@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 100)
        )
        let sparse = AuthMetadata(
            email: "Unknown account",
            plan: "chatgpt",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "same-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 200)
        )
        let saved = account(id: UUID(), alias: "primary", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: sparse])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        _ = try await SyncLiveAuthUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 400))
        )()

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertEqual(updated.email, "known@example.com")
        XCTAssertEqual(updated.plan, "plus")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 200))
    }

    func testSyncLiveAuthAllowsMissingLiveAuthAsNoop() async throws {
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let saved = account(id: UUID(), alias: "primary", metadata: metadata(email: "a@example.com", fingerprint: "fp-A"))
        let registry = AuthFileRegistry([:])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        let result = try await SyncLiveAuthUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry)
        )()

        XCTAssertEqual(result, .noop)
        XCTAssertEqual(repository.snapshotWriteCount, 0)
        XCTAssertEqual(repository.saveCount, 0)
    }

    func testSyncLiveAuthFailsWhenLiveAuthIsUnreadable() async throws {
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [], activeAccountID: nil, settings: AppSettings())
        )

        do {
            _ = try await SyncLiveAuthUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: AuthFileRegistry([:])),
                authReader: ThrowingAuthReader(error: .authFileUnreadable)
            )()
            XCTFail("Expected unreadable live auth to fail sync.")
        } catch CodexKeyringError.authFileUnreadable {
            XCTAssertEqual(repository.snapshotWriteCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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

    func testSyncLiveAuthSkipsUnknownChatGPTIdentifier() async throws {
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let liveAuth = AuthMetadata(
            email: "Unknown account",
            plan: "chatgpt",
            authMode: "chatgpt",
            accountIdentifier: AuthMetadata.unknownChatGPTAccountIdentifier,
            fingerprint: "live-fp",
            tokenExpiresAt: nil
        )
        let existing = AuthMetadata(
            email: "other@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: AuthMetadata.unknownChatGPTAccountIdentifier,
            fingerprint: "different-fp",
            tokenExpiresAt: nil
        )
        let stored = account(id: UUID(), alias: "chatgpt", metadata: existing)
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
        XCTAssertEqual(repository.saveCount, 0)
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

    func testSwitchAccountStopsWhenRotatedLiveAuthCannotBeSavedBack() async throws {
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
        let writeError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [accountA, accountB], activeAccountID: accountA.id, settings: AppSettings()),
            writeError: writeError
        )
        registry.set(newMeta, for: repository.snapshotURL(named: accountB.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        do {
            _ = try await SwitchAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: MockAuthReader(registry: registry),
                appController: MockAppController(outcome: .relaunched)
            )(accountID: accountB.id, restartCodexApp: false)
            XCTFail("Expected switch to stop when current live auth cannot be preserved.")
        } catch CodexKeyringError.currentAuthSyncFailed(let reason) {
            XCTAssertTrue(reason.contains("disk full"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, accountA.id)
        XCTAssertEqual(manifest.activeAccountID, accountA.id)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "fp-A-v2")
        XCTAssertEqual(installer.backupCount, 0)
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

    func testRefreshStateFailsWhenRotatedLiveAuthCannotBeSavedBack() async throws {
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
        let writeError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [accountA], activeAccountID: accountA.id, settings: AppSettings()),
            writeError: writeError
        )

        do {
            _ = try await RefreshStateUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry)
            )()
            XCTFail("Expected refresh to fail when current live auth cannot be preserved.")
        } catch CodexKeyringError.currentAuthSyncFailed(let reason) {
            XCTAssertTrue(reason.contains("disk full"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, accountA.id)
        XCTAssertEqual(manifest.accounts.first?.fingerprint, "fp-A-v1")
        XCTAssertEqual(manifest.activeAccountID, accountA.id)
    }

    func testRefreshStateAllowsMissingLiveAuthWithoutClearingSavedAccounts() async throws {
        let existing = account(id: UUID(), alias: "A", metadata: metadata(email: "a@example.com", fingerprint: "fp-A"))
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([:])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [existing], activeAccountID: existing.id, settings: AppSettings())
        )

        let state = try await RefreshStateUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry)
        )()

        XCTAssertEqual(state.accounts.map(\.id), [existing.id])
        XCTAssertEqual(state.activeAccountID, existing.id)
        XCTAssertNil(state.currentAuthMetadata)
    }

    func testRefreshStateFailsWhenLiveAuthIsUnreadable() async throws {
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [], activeAccountID: nil, settings: AppSettings())
        )

        do {
            _ = try await RefreshStateUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: AuthFileRegistry([:])),
                authReader: ThrowingAuthReader(error: .authFileUnreadable)
            )()
            XCTFail("Expected unreadable live auth to fail refresh.")
        } catch CodexKeyringError.authFileUnreadable {
            XCTAssertEqual(repository.snapshotWriteCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAccountStateFallsBackToStableIdentifierWhenFingerprintRotates() throws {
        let identifier = "user-A"
        let stored = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v1",
            tokenExpiresAt: nil
        )
        let live = AuthMetadata(
            email: "a@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-A-v2",
            tokenExpiresAt: nil
        )
        let account = account(id: UUID(), alias: "A", metadata: stored)

        let state = AccountState(
            accounts: [account],
            activeAccountID: nil,
            settings: AppSettings(),
            currentAuthMetadata: live
        )

        XCTAssertEqual(state.activeAccount?.id, account.id)
    }

    func testRemoveAccountReassignsActiveByStableIdentifierAfterRotation() async throws {
        let removedMeta = metadata(email: "old@example.com", fingerprint: "old")
        let identifier = "user-B"
        let stored = AuthMetadata(
            email: "b@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-B-v1",
            tokenExpiresAt: nil
        )
        let live = AuthMetadata(
            email: "b@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-B-v2",
            tokenExpiresAt: nil
        )
        let oldAccount = account(id: UUID(), alias: "old", metadata: removedMeta)
        let currentAccount = account(id: UUID(), alias: "current", metadata: stored)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: live])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, currentAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            )
        )

        let result = try await RemoveAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry)
        )(accountID: oldAccount.id)

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [currentAccount.id])
        XCTAssertEqual(manifest.activeAccountID, currentAccount.id)
        XCTAssertEqual(result.state.activeAccount?.id, currentAccount.id)
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "fp-B-v2")
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(repository.deletedSnapshots, [oldAccount.snapshotFileName])
    }

    func testRemoveAccountFailsWhenLiveAuthIsUnreadableBeforeMutatingManifest() async throws {
        let removedMeta = metadata(email: "old@example.com", fingerprint: "old")
        let remainingMeta = metadata(email: "current@example.com", fingerprint: "current")
        let removedAccount = account(id: UUID(), alias: "old", metadata: removedMeta)
        let remainingAccount = account(id: UUID(), alias: "current", metadata: remainingMeta)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: remainingMeta])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [removedAccount, remainingAccount],
                activeAccountID: removedAccount.id,
                settings: AppSettings()
            )
        )

        do {
            _ = try await RemoveAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: URLFailingAuthReader(
                    registry: registry,
                    failingURL: liveURL,
                    error: CodexKeyringError.authFileUnreadable
                )
            )(accountID: removedAccount.id)
            XCTFail("Expected removal to fail while live auth is unreadable.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [removedAccount.id, remainingAccount.id])
        XCTAssertEqual(manifest.activeAccountID, removedAccount.id)
        XCTAssertEqual(repository.saveCount, 0)
        XCTAssertTrue(repository.deletedSnapshots.isEmpty)
    }

    func testRemoveAccountDoesNotDeleteSnapshotWhenManifestSaveFails() async throws {
        let meta = metadata(email: "old@example.com", fingerprint: "old")
        let account = account(id: UUID(), alias: "old", metadata: meta)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: meta])
        let saveError = CodexKeyringError.fileSystemFailure(reason: "disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: AppSettings()
            ),
            saveError: saveError
        )

        do {
            _ = try await RemoveAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry)
            )(accountID: account.id)
            XCTFail("Expected removal to fail when manifest save fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, saveError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [account.id])
        XCTAssertEqual(repository.deletedSnapshots, [])
    }

    func testRemoveAccountRollsBackManifestWhenSnapshotDeleteFails() async throws {
        let meta = metadata(email: "old@example.com", fingerprint: "old")
        let account = account(id: UUID(), alias: "old", metadata: meta)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: meta])
        let deleteError = CodexKeyringError.fileSystemFailure(reason: "permission denied")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: AppSettings()
            ),
            deleteError: deleteError
        )

        do {
            _ = try await RemoveAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry)
            )(accountID: account.id)
            XCTFail("Expected removal to fail when snapshot deletion fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, deleteError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [account.id])
        XCTAssertEqual(manifest.activeAccountID, account.id)
        XCTAssertEqual(repository.saveCount, 2)
    }

    func testRemoveAccountRollsBackWhenSnapshotDeleteFailsDespiteUnconfirmedExistence() async throws {
        let meta = metadata(email: "old@example.com", fingerprint: "old")
        let account = account(id: UUID(), alias: "old", metadata: meta)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: meta])
        let deleteError = CodexKeyringError.fileSystemFailure(reason: "permission denied")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: AppSettings()
            ),
            deleteError: deleteError,
            snapshotExists: false
        )

        do {
            _ = try await RemoveAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry)
            )(accountID: account.id)
            XCTFail("Expected removal to fail when snapshot deletion fails.")
        } catch {
            XCTAssertEqual(error.localizedDescription, deleteError.localizedDescription)
        }

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [account.id])
        XCTAssertEqual(manifest.activeAccountID, account.id)
        XCTAssertEqual(repository.saveCount, 2)
        XCTAssertTrue(repository.deletedSnapshots.isEmpty)
    }

    func testRemoveAccountReportsWhenManifestRollbackFailsAfterSnapshotDeleteFails() async throws {
        let meta = metadata(email: "old@example.com", fingerprint: "old")
        let account = account(id: UUID(), alias: "old", metadata: meta)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: meta])
        let deleteError = CodexKeyringError.fileSystemFailure(reason: "permission denied")
        let rollbackError = CodexKeyringError.fileSystemFailure(reason: "rollback disk full")
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: AppSettings()
            ),
            deleteError: deleteError,
            saveErrorsByAttempt: [2: rollbackError]
        )

        do {
            _ = try await RemoveAccountUseCase(
                repository: repository,
                installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
                authReader: MockAuthReader(registry: registry)
            )(accountID: account.id)
            XCTFail("Expected removal to fail when snapshot delete and rollback both fail.")
        } catch CodexKeyringError.manifestRollbackFailed(let originalReason, let rollbackReason) {
            XCTAssertTrue(originalReason.contains("permission denied"))
            XCTAssertTrue(rollbackReason.contains("rollback disk full"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let manifest = try await repository.load()
        XCTAssertTrue(manifest.accounts.isEmpty)
        XCTAssertNil(manifest.activeAccountID)
        XCTAssertEqual(repository.saveCount, 1)
    }

    func testSwitchAccountCapturesOutgoingAndAppliesIncomingPreferencesWhenEnabled() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        var newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        // The incoming account already has a saved preferences snapshot we
        // expect to be applied to the live Codex files.
        newAccount.agentPreferences = AccountAgentPreferences(
            model: "gpt-5.5",
            modelReasoningEffort: "xhigh",
            approvalPolicy: "never",
            approvalsReviewer: "guardian_subagent",
            sandboxMode: "workspace-write",
            agentMode: "full-access",
            skipFullAccessConfirm: true
        )
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        let settings = AppSettings(
            restartCodexAppAfterSwitch: true,
            launchAtLogin: false,
            allowNetworkQuotaAPIs: false,
            preserveAgentPreferencesPerAccount: true
        )
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)
        let appController = MockAppController(outcome: .relaunched)
        let outgoingCaptured = AccountAgentPreferences(
            model: "gpt-5",
            modelReasoningEffort: "medium",
            agentMode: "auto-review"
        )
        let port = MockAgentPreferencesPort(captureValues: [outgoingCaptured])

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: MockAuthReader(registry: registry),
            appController: appController,
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: true)

        let saved = try await repository.load()
        XCTAssertEqual(port.captureCallCount, 1)
        XCTAssertEqual(port.applied.count, 1)
        XCTAssertEqual(port.applied.first?.model, "gpt-5.5")
        XCTAssertEqual(port.applied.first?.agentMode, "full-access")
        XCTAssertEqual(port.applied.first?.skipFullAccessConfirm, true)
        XCTAssertEqual(
            saved.accounts.first(where: { $0.id == oldAccount.id })?.agentPreferences?.model,
            "gpt-5"
        )
        XCTAssertEqual(
            saved.accounts.first(where: { $0.id == oldAccount.id })?.agentPreferences?.agentMode,
            "auto-review"
        )
        XCTAssertTrue(result.appliedAgentPreferences)
        XCTAssertNil(result.agentPreferencesWarningReason)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertTrue(appController.lastBeforeRelaunchRan)
    }

    func testSwitchAccountWarnsWhenOutgoingAgentPreferenceCaptureFails() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        var newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        newAccount.agentPreferences = AccountAgentPreferences(model: "gpt-5.5")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        let settings = AppSettings(
            restartCodexAppAfterSwitch: true,
            preserveAgentPreferencesPerAccount: true
        )
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let port = MockAgentPreferencesPort(
            captureError: CodexKeyringError.fileSystemFailure(reason: "permission denied")
        )

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            appController: MockAppController(outcome: .relaunched),
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: true)

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, newAccount.id)
        XCTAssertNil(saved.accounts.first(where: { $0.id == oldAccount.id })?.agentPreferences)
        XCTAssertEqual(port.captureCallCount, 1)
        XCTAssertEqual(port.applied.first?.model, "gpt-5.5")
        XCTAssertTrue(result.appliedAgentPreferences)
        XCTAssertTrue(result.agentPreferencesWarningReason?.contains("permission denied") == true)
    }

    func testSwitchAccountRelaunchesAndWarnsWhenIncomingPreferenceApplyFails() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        var newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        newAccount.agentPreferences = AccountAgentPreferences(model: "gpt-5.5")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        let settings = AppSettings(
            restartCodexAppAfterSwitch: true,
            preserveAgentPreferencesPerAccount: true
        )
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let appController = MockAppController(outcome: .relaunched)
        let port = MockAgentPreferencesPort(
            applyError: CodexKeyringError.fileSystemFailure(reason: "config denied")
        )

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            appController: appController,
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: true)

        XCTAssertEqual(result.restartOutcome, .relaunched)
        XCTAssertNil(result.restartFailureReason)
        XCTAssertFalse(result.appliedAgentPreferences)
        XCTAssertEqual(port.applyCallCount, 1)
        XCTAssertTrue(port.applied.isEmpty)
        XCTAssertTrue(result.agentPreferencesWarningReason?.contains("config denied") == true)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertTrue(appController.lastBeforeRelaunchRan)
    }

    func testSwitchAccountDoesNotTouchPreferencesWhenFeatureOff() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        var newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        newAccount.agentPreferences = AccountAgentPreferences(model: "gpt-5.5")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        // The feature defaults to ON now, so this test must opt out explicitly.
        let settings = AppSettings(preserveAgentPreferencesPerAccount: false)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let port = MockAgentPreferencesPort()

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            appController: MockAppController(outcome: .relaunched),
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: true)

        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertEqual(port.applied.count, 0)
        XCTAssertFalse(result.appliedAgentPreferences)
    }

    func testSwitchAccountRestoresProjectArrangementEvenWhenAgentPrefsOff() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        let newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        let settings = AppSettings(preserveAgentPreferencesPerAccount: false)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let arrangement = CodexProjectArrangement(
            projectOrder: ["/before-a", "remote-before"],
            pinnedProjectIDs: ["/before-a"],
            sidebarOrganizeMode: "manual"
        )
        let port = MockAgentPreferencesPort(projectArrangement: arrangement)

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            appController: MockAppController(outcome: .relaunched),
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: true)

        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertEqual(port.applied.count, 0)
        XCTAssertEqual(port.projectArrangementCaptureCallCount, 1)
        XCTAssertEqual(port.restoredProjectArrangements, [arrangement])
        XCTAssertFalse(result.appliedAgentPreferences)
    }

    func testSwitchAccountWarnsWhenProjectArrangementCaptureFails() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        let newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        let settings = AppSettings(preserveAgentPreferencesPerAccount: false)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let port = MockAgentPreferencesPort(
            projectArrangementCaptureError: CodexKeyringError.fileSystemFailure(reason: "global state denied")
        )

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            appController: MockAppController(outcome: .relaunched),
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: true)

        XCTAssertEqual(result.state.activeAccountID, newAccount.id)
        XCTAssertEqual(result.restartOutcome, .relaunched)
        XCTAssertNil(result.restartFailureReason)
        XCTAssertEqual(port.projectArrangementCaptureCallCount, 1)
        XCTAssertTrue(port.restoredProjectArrangements.isEmpty)
        XCTAssertTrue(result.projectArrangementWarningReason?.contains("global state denied") == true)
    }

    func testSwitchAccountRelaunchesAndWarnsWhenProjectArrangementRestoreFails() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        let newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        let settings = AppSettings(preserveAgentPreferencesPerAccount: false)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let arrangement = CodexProjectArrangement(
            projectOrder: ["/before-a"],
            pinnedProjectIDs: ["/before-a"],
            sidebarOrganizeMode: "manual"
        )
        let appController = MockAppController(outcome: .relaunched)
        let port = MockAgentPreferencesPort(
            projectArrangement: arrangement,
            projectArrangementRestoreError: CodexKeyringError.fileSystemFailure(reason: "state denied")
        )

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            appController: appController,
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: true)

        XCTAssertEqual(result.restartOutcome, .relaunched)
        XCTAssertNil(result.restartFailureReason)
        XCTAssertEqual(port.projectArrangementRestoreCallCount, 1)
        XCTAssertTrue(port.restoredProjectArrangements.isEmpty)
        XCTAssertTrue(result.projectArrangementWarningReason?.contains("state denied") == true)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertTrue(appController.lastBeforeRelaunchRan)
    }

    func testSwitchAccountDoesNotApplyPreferencesWithoutRestart() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        var newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        newAccount.agentPreferences = AccountAgentPreferences(model: "gpt-5.5")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        let settings = AppSettings(preserveAgentPreferencesPerAccount: true)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let port = MockAgentPreferencesPort(captureValues: [AccountAgentPreferences(model: "gpt-5")])

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            appController: MockAppController(outcome: .relaunched),
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: false)

        // Without a restart the pref capture would race the running Codex App
        // when it later quits, so we deliberately skip the whole orchestration.
        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertEqual(port.applied.count, 0)
        XCTAssertFalse(result.appliedAgentPreferences)
    }

    func testSwitchAccountDoesNotStartCodexAppWhenNotRunning() async throws {
        let oldMeta = metadata(email: "old@example.com", fingerprint: "old")
        let newMeta = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: oldMeta)
        var newAccount = account(id: UUID(), alias: "new", metadata: newMeta)
        newAccount.agentPreferences = AccountAgentPreferences(model: "gpt-5.5")
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: oldMeta])
        let settings = AppSettings(preserveAgentPreferencesPerAccount: true)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount, newAccount],
                activeAccountID: oldAccount.id,
                settings: settings
            )
        )
        registry.set(newMeta, for: repository.snapshotURL(named: newAccount.snapshotFileName))
        let appController = MockAppController(outcome: .relaunched)
        appController.isRunning = false
        let port = MockAgentPreferencesPort(captureValues: [AccountAgentPreferences(model: "gpt-5")])

        let result = try await SwitchAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            appController: appController,
            preferencesPort: port
        )(accountID: newAccount.id, restartCodexApp: true)

        XCTAssertEqual(result.restartOutcome, .wasNotRunning)
        XCTAssertEqual(appController.restartCallCount, 0)
        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertEqual(port.applied.count, 0)
        XCTAssertFalse(result.appliedAgentPreferences)
        XCTAssertEqual(registry.metadata(for: liveURL)?.fingerprint, "new")
    }

    func testAppSettingsDecodesLegacyManifestWithoutPreserveAgentPrefs() throws {
        let json = Data("""
        {
          "restartCodexAppAfterSwitch": true,
          "launchAtLogin": false,
          "allowNetworkQuotaAPIs": false
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertTrue(decoded.restartCodexAppAfterSwitch)
        // Legacy manifests inherit the new default-on behavior.
        XCTAssertTrue(decoded.preserveAgentPreferencesPerAccount)
    }

    func testAppSettingsHonoursExplicitlyDisabledPreserveAgentPrefs() throws {
        let json = Data("""
        {
          "restartCodexAppAfterSwitch": true,
          "launchAtLogin": false,
          "allowNetworkQuotaAPIs": false,
          "preserveAgentPreferencesPerAccount": false
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertFalse(decoded.preserveAgentPreferencesPerAccount)
    }

    func testAppSettingsDefaultsRestartCodexAppOn() {
        let defaults = AppSettings()
        XCTAssertTrue(defaults.restartCodexAppAfterSwitch)
    }

    func testAppSettingsDefaultsPreserveAgentPreferencesOn() {
        let defaults = AppSettings()
        XCTAssertTrue(defaults.preserveAgentPreferencesPerAccount)
    }

    func testAppSettingsDefaultsQuotaRefreshInterval() {
        let defaults = AppSettings()
        XCTAssertEqual(defaults.quotaRefreshIntervalMinutes, 15)
    }

    func testAppSettingsNormalizesQuotaRefreshInterval() throws {
        let json = Data("""
        {
          "allowNetworkQuotaAPIs": true,
          "quotaRefreshIntervalMinutes": 7
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(decoded.quotaRefreshIntervalMinutes, 15)
    }

    func testAppSettingsDecodesMissingRestartAsTrue() throws {
        let json = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertTrue(decoded.restartCodexAppAfterSwitch)
    }

    func testAppSettingsRespectsExplicitRestartFalse() throws {
        let json = Data("""
        {
          "restartCodexAppAfterSwitch": false
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertFalse(decoded.restartCodexAppAfterSwitch)
    }

    func testUpdateSettingsPersistsRestartPreference() async throws {
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(
                    restartCodexAppAfterSwitch: true,
                    launchAtLogin: true,
                    allowNetworkQuotaAPIs: true,
                    quotaRefreshIntervalMinutes: 30
                )
            )
        )

        let settings = try await UpdateSettingsUseCase(repository: repository)
            .setRestartCodexAppAfterSwitch(false)

        let saved = try await repository.load()
        XCTAssertFalse(settings.restartCodexAppAfterSwitch)
        XCTAssertFalse(saved.settings.restartCodexAppAfterSwitch)
        XCTAssertTrue(saved.settings.launchAtLogin)
        XCTAssertTrue(saved.settings.allowNetworkQuotaAPIs)
        XCTAssertEqual(saved.settings.quotaRefreshIntervalMinutes, 30)
    }

    func testUpdateSettingsSkipsSaveWhenValueIsUnchanged() async throws {
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(
                    restartCodexAppAfterSwitch: false,
                    launchAtLogin: false,
                    allowNetworkQuotaAPIs: true,
                    quotaRefreshIntervalMinutes: 15
                )
            )
        )

        let settings = try await UpdateSettingsUseCase(repository: repository)
            .setRestartCodexAppAfterSwitch(false)

        XCTAssertFalse(settings.restartCodexAppAfterSwitch)
        XCTAssertEqual(repository.saveCount, 0)
    }

    func testUpdateSettingsSkipsSaveWhenIntervalNormalizesToCurrentValue() async throws {
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(quotaRefreshIntervalMinutes: 15)
            )
        )

        let settings = try await UpdateSettingsUseCase(repository: repository)
            .setQuotaRefreshIntervalMinutes(7)

        XCTAssertEqual(settings.quotaRefreshIntervalMinutes, 15)
        XCTAssertEqual(repository.saveCount, 0)
    }

    func testAliasPolicyFallsBackAndUniquifiesCaseInsensitively() {
        let policy = AliasPolicy()

        XCTAssertEqual(policy.clean("  ", fallback: "fallback"), "fallback")
        XCTAssertEqual(policy.clean("  ", fallback: "  "), "account")
        XCTAssertEqual(policy.cleanAllowingEmpty("  "), "")
        XCTAssertEqual(policy.cleanAllowingEmpty("  display name\n"), "display name")
        XCTAssertEqual(
            policy.uniquified("Work", existingAliases: ["work", "work-2"]),
            "Work-3"
        )
        XCTAssertEqual(
            policy.suggested(for: metadata(email: "", fingerprint: "empty")),
            "account"
        )
        XCTAssertEqual(
            policy.suggested(for: metadata(email: "  person@example.com  ", fingerprint: "spaced")),
            "person"
        )
        XCTAssertEqual(
            policy.suggested(for: metadata(email: "  ", fingerprint: "blank")),
            "account"
        )
    }

    func testRenameAccountSkipsSaveWhenAliasIsUnchangedAfterCleaning() async throws {
        let original = metadata(email: "primary@example.com", fingerprint: "primary")
        let saved = account(id: UUID(), alias: "primary", metadata: original)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: original])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )

        let result = try await RenameAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(accountID: saved.id, newAlias: "  primary\n")

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertFalse(result.didRename)
        XCTAssertEqual(result.newAlias, "primary")
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "primary")
        XCTAssertEqual(repository.saveCount, 0)
        XCTAssertEqual(updated.alias, "primary")
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 1))
    }

    func testRenameAccountCanClearAliasAndSortsByDisplayNameFallback() async throws {
        let source = metadata(email: "zeta@example.com", fingerprint: "zeta")
        let other = metadata(email: "alpha@example.com", fingerprint: "alpha")
        let accountA = account(id: UUID(), alias: "zeta", metadata: source)
        let accountB = account(id: UUID(), alias: "alpha", metadata: other)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: source])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [accountA, accountB], activeAccountID: accountA.id, settings: AppSettings())
        )

        let result = try await RenameAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(accountID: accountA.id, newAlias: "  ")

        let manifest = try await repository.load()
        let renamed = try XCTUnwrap(manifest.accounts.first { $0.id == accountA.id })
        XCTAssertTrue(result.didRename)
        XCTAssertEqual(result.newAlias, "")
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(renamed.alias, "")
        XCTAssertEqual(renamed.displayName, "zeta@example.com")
        XCTAssertEqual(renamed.updatedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(manifest.accounts.map(\.displayName), ["alpha", "zeta@example.com"])
    }

    func testRenameAccountUniquifiesChangedAliasAndUpdatesTimestamp() async throws {
        let source = metadata(email: "work@example.com", fingerprint: "work")
        let other = metadata(email: "personal@example.com", fingerprint: "personal")
        let accountA = account(id: UUID(), alias: "work", metadata: source)
        let accountB = account(id: UUID(), alias: "personal", metadata: other)
        let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
        let registry = AuthFileRegistry([liveURL: source])
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [accountA, accountB], activeAccountID: accountA.id, settings: AppSettings())
        )

        let result = try await RenameAccountUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: liveURL, registry: registry),
            authReader: MockAuthReader(registry: registry),
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(accountID: accountA.id, newAlias: " personal ")

        let manifest = try await repository.load()
        let renamed = try XCTUnwrap(manifest.accounts.first { $0.id == accountA.id })
        let untouched = try XCTUnwrap(manifest.accounts.first { $0.id == accountB.id })
        XCTAssertTrue(result.didRename)
        XCTAssertEqual(result.newAlias, "personal-2")
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(manifest.accounts.map(\.alias), ["personal", "personal-2"])
        XCTAssertEqual(renamed.updatedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(untouched.updatedAt, Date(timeIntervalSince1970: 1))
    }

    func testRefreshAccountQuotasDoesNotQueryWhenNetworkAPIsDisabled() async throws {
        let saved = account(id: UUID(), alias: "plus", metadata: metadata(email: "p@example.com", fingerprint: "p"))
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: AppSettings())
        )
        let quotaQuery = MockQuotaQuery { request in
            AccountQuotaQueryResult(state: .available(quotaSnapshot(accountID: request.account.id)))
        }

        let result = try await RefreshAccountQuotasUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: URL(fileURLWithPath: "/tmp/auth.json"), registry: AuthFileRegistry([:])),
            query: quotaQuery
        )()

        XCTAssertTrue(result.states.isEmpty)
        XCTAssertTrue(quotaQuery.requests.isEmpty)
    }

    func testRefreshAccountQuotasSkipsApiKeyAndKeepsOtherFailuresIsolated() async throws {
        let good = account(id: UUID(), alias: "good", metadata: metadata(email: "good@example.com", fingerprint: "good"))
        let apiMetadata = AuthMetadata(
            email: "api",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: "api-key",
            fingerprint: "api",
            tokenExpiresAt: nil
        )
        let api = account(id: UUID(), alias: "api", metadata: apiMetadata)
        let failing = account(id: UUID(), alias: "failing", metadata: metadata(email: "fail@example.com", fingerprint: "fail"))
        let settings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [good, api, failing], activeAccountID: good.id, settings: settings)
        )
        let quotaQuery = MockQuotaQuery { request in
            if request.account.id == failing.id {
                throw CodexKeyringError.quotaQueryFailed(reason: "network down")
            }
            return AccountQuotaQueryResult(state: .available(quotaSnapshot(accountID: request.account.id)))
        }

        let result = try await RefreshAccountQuotasUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: URL(fileURLWithPath: "/tmp/auth.json"), registry: AuthFileRegistry([:])),
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 123))
        )()

        XCTAssertEqual(quotaQuery.requests.map(\.account.id), [good.id, failing.id])
        XCTAssertEqual(result.states[good.id]?.phase, .available)
        XCTAssertEqual(result.states[api.id]?.phase, .unsupported)
        XCTAssertEqual(result.states[failing.id]?.phase, .error)
    }

    func testRefreshAccountQuotasReportsMissingSnapshotFromQuery() async throws {
        let saved = account(id: UUID(), alias: "saved", metadata: metadata(email: "p@example.com", fingerprint: "p"))
        let settings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: settings)
        )
        let quotaQuery = MockQuotaQuery { _ in
            throw CodexKeyringError.authFileMissing(URL(fileURLWithPath: "/tmp/missing.auth.json"))
        }

        let result = try await RefreshAccountQuotasUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: URL(fileURLWithPath: "/tmp/auth.json"), registry: AuthFileRegistry([:])),
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 123))
        )()

        XCTAssertEqual(quotaQuery.requests.map(\.account.id), [saved.id])
        XCTAssertEqual(result.states[saved.id]?.phase, .error)
        XCTAssertEqual(result.states[saved.id]?.message, "The saved auth snapshot is missing.")
        XCTAssertEqual(result.states[saved.id]?.updatedAt, Date(timeIntervalSince1970: 123))
    }

    func testRefreshAccountQuotasPreservesUnreadableSnapshotFailure() async throws {
        let saved = account(id: UUID(), alias: "saved", metadata: metadata(email: "p@example.com", fingerprint: "p"))
        let settings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: settings)
        )
        let quotaQuery = MockQuotaQuery { _ in
            throw CodexKeyringError.authFileUnreadable
        }

        let result = try await RefreshAccountQuotasUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: URL(fileURLWithPath: "/tmp/auth.json"), registry: AuthFileRegistry([:])),
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 456))
        )()

        XCTAssertEqual(quotaQuery.requests.map(\.account.id), [saved.id])
        XCTAssertEqual(result.states[saved.id]?.phase, .error)
        XCTAssertEqual(result.states[saved.id]?.message, "The selected auth file is not readable JSON.")
        XCTAssertEqual(result.states[saved.id]?.updatedAt, Date(timeIntervalSince1970: 456))
    }

    func testRefreshAccountQuotasUpdatesManifestWhenTokenRefreshChangesMetadata() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "old")
        let refreshed = AuthMetadata(
            email: "new@example.com",
            plan: "pro",
            authMode: "chatgpt",
            accountIdentifier: "account-new",
            fingerprint: "new-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 456)
        )
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let settings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: settings)
        )
        let quotaQuery = MockQuotaQuery { request in
            AccountQuotaQueryResult(
                state: .available(quotaSnapshot(accountID: request.account.id)),
                updatedMetadata: refreshed
            )
        }

        _ = try await RefreshAccountQuotasUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: URL(fileURLWithPath: "/tmp/auth.json"), registry: AuthFileRegistry([:])),
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 999))
        )()

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertEqual(updated.email, "new@example.com")
        XCTAssertEqual(updated.plan, "pro")
        XCTAssertEqual(updated.accountIdentifier, "account-new")
        XCTAssertEqual(updated.fingerprint, "new-fingerprint")
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 999))
    }

    func testRefreshAccountQuotasDoesNotOverwriteUsefulMetadataWithPlaceholders() async throws {
        let original = AuthMetadata(
            email: "known@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-known",
            fingerprint: "old-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 100)
        )
        let refreshed = AuthMetadata(
            email: "Unknown account",
            plan: "chatgpt",
            authMode: "chatgpt",
            accountIdentifier: "",
            fingerprint: "new-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 456)
        )
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let settings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = InMemoryAccountRepository(
            manifest: AccountManifest(accounts: [saved], activeAccountID: saved.id, settings: settings)
        )
        let quotaQuery = MockQuotaQuery { request in
            AccountQuotaQueryResult(
                state: .available(quotaSnapshot(accountID: request.account.id)),
                updatedMetadata: refreshed
            )
        }

        _ = try await RefreshAccountQuotasUseCase(
            repository: repository,
            installer: MockInstaller(liveAuthFileURL: URL(fileURLWithPath: "/tmp/auth.json"), registry: AuthFileRegistry([:])),
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 999))
        )()

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertEqual(updated.email, "known@example.com")
        XCTAssertEqual(updated.plan, "plus")
        XCTAssertEqual(updated.accountIdentifier, "account-known")
        XCTAssertEqual(updated.fingerprint, "new-fingerprint")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 456))
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 999))
    }
}

private func exampleLoginURL(
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> URL {
    try XCTUnwrap(URL(string: "https://example.test/login"), file: file, line: line)
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
        tokenExpiresAt: metadata.tokenExpiresAt
    )
}

private func quotaSnapshot(accountID: UUID) -> AccountQuotaSnapshot {
    AccountQuotaSnapshot(
        accountID: accountID,
        planType: "plus",
        email: "person@example.com",
        fetchedAt: Date(timeIntervalSince1970: 100),
        buckets: [
            QuotaBucket(
                limitID: "codex",
                limitName: nil,
                planType: "plus",
                windows: [
                    QuotaWindow(
                        usedPercent: 20,
                        windowDurationMinutes: 5 * 60,
                        resetsAt: Date(timeIntervalSince1970: 200)
                    )
                ],
                credits: nil,
                rateLimitReachedType: nil
            )
        ],
        endpoint: "https://chatgpt.test/backend-api/wham/usage"
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

private struct ThrowingAuthReader: AuthFileReading {
    let error: CodexKeyringError

    func read(from url: URL) async throws -> AuthMetadata {
        throw error
    }
}

private final class URLFailingAuthReader: AuthFileReading, @unchecked Sendable {
    private let registry: AuthFileRegistry
    private let failingURL: URL
    private let error: CodexKeyringError

    init(registry: AuthFileRegistry, failingURL: URL, error: CodexKeyringError) {
        self.registry = registry
        self.failingURL = failingURL
        self.error = error
    }

    func read(from url: URL) async throws -> AuthMetadata {
        if url == failingURL {
            throw error
        }
        guard let metadata = registry.metadata(for: url) else {
            throw CodexKeyringError.authFileMissing(url)
        }
        return metadata
    }
}

private final class MockInstaller: CodexAuthInstalling, @unchecked Sendable {
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

private final class MockAppController: CodexAppControlling, @unchecked Sendable {
    var isRunning = true
    private let outcome: CodexAppRestartOutcome
    private let restartError: Error?
    private(set) var restartCallCount = 0
    private(set) var lastBeforeRelaunchRan = false

    init(outcome: CodexAppRestartOutcome, restartError: Error? = nil) {
        self.outcome = outcome
        self.restartError = restartError
    }

    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome {
        restartCallCount += 1
        if case .wasNotRunning = outcome {
            return outcome
        }
        try await beforeRelaunch()
        lastBeforeRelaunchRan = true
        if let restartError {
            throw restartError
        }
        return outcome
    }
}

private final class MockQuotaQuery: AccountQuotaQuerying, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [AccountQuotaQueryRequest] = []
    private let handler: (AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult

    init(handler: @escaping (AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult) {
        self.handler = handler
    }

    var requests: [AccountQuotaQueryRequest] {
        lock.withLock { recordedRequests }
    }

    func queryQuota(for request: AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult {
        lock.withLock { recordedRequests.append(request) }
        return try await handler(request)
    }
}

private final class MockAgentPreferencesPort: CodexAgentPreferencesPorting, @unchecked Sendable {
    private let lock = NSLock()
    private var captureValues: [AccountAgentPreferences]
    private var projectArrangement: CodexProjectArrangement
    private let captureError: Error?
    private let projectArrangementCaptureError: Error?
    private let applyError: Error?
    private let projectArrangementRestoreError: Error?
    private var captureIndex = 0
    private(set) var captureCallCount = 0
    private(set) var applyCallCount = 0
    private(set) var projectArrangementCaptureCallCount = 0
    private(set) var projectArrangementRestoreCallCount = 0
    private(set) var applied: [AccountAgentPreferences] = []
    private(set) var restoredProjectArrangements: [CodexProjectArrangement] = []

    init(
        captureValues: [AccountAgentPreferences] = [],
        projectArrangement: CodexProjectArrangement = CodexProjectArrangement(),
        captureError: Error? = nil,
        projectArrangementCaptureError: Error? = nil,
        applyError: Error? = nil,
        projectArrangementRestoreError: Error? = nil
    ) {
        self.captureValues = captureValues
        self.projectArrangement = projectArrangement
        self.captureError = captureError
        self.projectArrangementCaptureError = projectArrangementCaptureError
        self.applyError = applyError
        self.projectArrangementRestoreError = projectArrangementRestoreError
    }

    func captureCurrent() async throws -> AccountAgentPreferences {
        if let captureError {
            lock.withLock { captureCallCount += 1 }
            throw captureError
        }
        return lock.withLock {
            captureCallCount += 1
            guard captureIndex < captureValues.count else {
                return AccountAgentPreferences()
            }
            defer { captureIndex += 1 }
            return captureValues[captureIndex]
        }
    }

    func apply(_ preferences: AccountAgentPreferences) async throws {
        lock.withLock { applyCallCount += 1 }
        if let applyError {
            throw applyError
        }
        lock.withLock { applied.append(preferences) }
    }

    func captureProjectArrangement() async throws -> CodexProjectArrangement {
        if let projectArrangementCaptureError {
            lock.withLock { projectArrangementCaptureCallCount += 1 }
            throw projectArrangementCaptureError
        }
        return lock.withLock {
            projectArrangementCaptureCallCount += 1
            return projectArrangement
        }
    }

    func restoreProjectArrangement(_ arrangement: CodexProjectArrangement) async throws {
        lock.withLock { projectArrangementRestoreCallCount += 1 }
        if let projectArrangementRestoreError {
            throw projectArrangementRestoreError
        }
        lock.withLock { restoredProjectArrangements.append(arrangement) }
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
