import Foundation
@testable import CodexKeyringDomain

final class LoginNewAccountUseCaseFixture {
    let old = metadata(email: "old@example.com", fingerprint: "old")
    let new = metadata(email: "new@example.com", fingerprint: "new")
    let liveURL = URL(fileURLWithPath: "/tmp/live-auth.json")
    let preLoginStage = URL(fileURLWithPath: "/tmp/pre-login-1.json")
    let newLoginStage = URL(fileURLWithPath: "/tmp/new-login-2.json")

    let oldAccount: CodexAccount
    let registry: AuthFileRegistry
    let repository: InMemoryAccountRepository
    let installer: MockInstaller
    let loginService: MockLoginService

    init(
        saveError: Error? = nil,
        restoreError: Error? = nil,
        removeStagedError: Error? = nil
    ) {
        oldAccount = account(id: UUID(), alias: "old", metadata: old)
        registry = AuthFileRegistry([liveURL: old])
        repository = InMemoryAccountRepository(
            manifest: AccountManifest(
                accounts: [oldAccount],
                activeAccountID: oldAccount.id,
                settings: AppSettings()
            ),
            saveError: saveError
        )
        installer = MockInstaller(
            liveAuthFileURL: liveURL,
            registry: registry,
            restoreError: restoreError,
            removeStagedError: removeStagedError
        )
        loginService = MockLoginService { [registry, liveURL, new] urlOpener in
            try await urlOpener(exampleLoginURL())
            registry.set(new, for: liveURL)
        }
    }

    func login(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void = { _ in }
    ) async throws -> LoginNewAccountResult {
        try await makeUseCase().callAsFunction(openAuthURL: openAuthURL)
    }

    func makeUseCase() -> LoginNewAccountUseCase {
        LoginNewAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: MockAuthReader(registry: registry),
            loginService: loginService,
            clock: FixedClock(Date(timeIntervalSince1970: 100))
        )
    }
}
