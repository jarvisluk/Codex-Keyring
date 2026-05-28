import Foundation
import XCTest
@testable import CodexKeyringDomain

struct SwitchAccountValidationFixture {
    let oldAccount: CodexAccount
    let newAccount: CodexAccount
    let liveURL: URL
    let registry: AuthFileRegistry
    let repository: InMemoryAccountRepository
    let installer: MockInstaller

    init(
        oldMetadata: AuthMetadata = metadata(email: "old@example.com", fingerprint: "old"),
        liveMetadata: AuthMetadata? = nil,
        newMetadata: AuthMetadata = metadata(email: "new@example.com", fingerprint: "new"),
        seedSnapshot: Bool = true
    ) {
        let liveMetadata = liveMetadata ?? oldMetadata
        self.oldAccount = account(id: UUID(), alias: "old", metadata: oldMetadata)
        self.newAccount = account(id: UUID(), alias: "new", metadata: newMetadata)
        self.liveURL = testAuthURL("live-auth.json")
        self.registry = AuthFileRegistry([self.liveURL: liveMetadata])
        self.repository = accountRepository(
            accounts: [oldAccount, newAccount],
            activeAccountID: oldAccount.id
        )
        self.installer = MockInstaller(liveAuthFileURL: liveURL, registry: registry)

        if seedSnapshot {
            registry.set(newMetadata, for: snapshotURL)
        }
    }

    var snapshotURL: URL {
        repository.snapshotURL(named: newAccount.snapshotFileName)
    }

    func useCase(authReader: AuthFileReading) -> SwitchAccountUseCase {
        switchAccountUseCase(
            repository: repository,
            installer: installer,
            registry: registry,
            authReader: authReader,
            appController: MockAppController(outcome: .relaunched)
        )
    }

    func switchToNewAccount(authReader: AuthFileReading) async throws -> SwitchAccountResult {
        try await useCase(authReader: authReader)(
            accountID: newAccount.id,
            restartCodexApp: true
        )
    }

    func snapshotFailingReader(
        error: CodexKeyringError = .authFileUnreadable
    ) -> AuthFileReading {
        URLFailingAuthReader(
            registry: registry,
            failingURL: snapshotURL,
            error: error
        )
    }

    func liveFailingReader(
        error: CodexKeyringError = .authFileUnreadable
    ) -> AuthFileReading {
        URLFailingAuthReader(
            registry: registry,
            failingURL: liveURL,
            error: error
        )
    }

    func assertNoInstallAttempt(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(installer.backupCount, 0, file: file, line: line)
        XCTAssertEqual(installer.installCount, 0, file: file, line: line)
    }

    func assertNoManifestWrite(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(repository.saveCount, 0, file: file, line: line)
        XCTAssertEqual(repository.snapshotWriteCount, 0, file: file, line: line)
    }
}
