import Foundation

public struct LoginNewAccountResult: Sendable {
    public let state: AccountState
    public let savedAlias: String
}

/// Run the Codex browser login flow, save the newly written auth as a snapshot,
/// then restore the user's previous live auth so the active account is unchanged.
public struct LoginNewAccountUseCase: Sendable {
    private let repository: any AccountRepository
    private let installer: any CodexAuthInstalling
    private let authReader: any AuthFileReading
    private let loginService: any CodexLoginServicing
    private let clock: any Clock
    private let aliasPolicy: AliasPolicy

    public init(
        repository: any AccountRepository,
        installer: any CodexAuthInstalling,
        authReader: any AuthFileReading,
        loginService: any CodexLoginServicing,
        clock: any Clock = SystemClock(),
        aliasPolicy: AliasPolicy = AliasPolicy()
    ) {
        self.repository = repository
        self.installer = installer
        self.authReader = authReader
        self.loginService = loginService
        self.clock = clock
        self.aliasPolicy = aliasPolicy
    }

    public func callAsFunction(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws -> LoginNewAccountResult {
        let restoreURL = try await installer.stageLiveAuthIfPresent(prefix: "pre-login")
        var newLoginURL: URL?
        let result: LoginNewAccountResult

        do {
            try await loginService.loginWithChatGPT(openAuthURL: openAuthURL)
            let stagedLoginURL = try await installer.stageRequiredLiveAuth(prefix: "new-login")
            newLoginURL = stagedLoginURL
            try await installer.restoreLiveAuth(from: restoreURL)

            let addResult = try await AddAccountUseCase(
                repository: repository,
                installer: installer,
                authReader: authReader,
                clock: clock,
                aliasPolicy: aliasPolicy
            )(
                sourceURL: stagedLoginURL,
                requestedAlias: nil,
                activate: false
            )

            let state = try await RefreshStateUseCase(
                repository: repository,
                installer: installer,
                authReader: authReader
            )()

            result = LoginNewAccountResult(
                state: state,
                savedAlias: addResult.savedAlias
            )
        } catch {
            try? await installer.restoreLiveAuth(from: restoreURL)
            await installer.removeStagedAuth(restoreURL)
            await installer.removeStagedAuth(newLoginURL)
            throw error
        }

        await installer.removeStagedAuth(restoreURL)
        await installer.removeStagedAuth(newLoginURL)
        return result
    }
}
