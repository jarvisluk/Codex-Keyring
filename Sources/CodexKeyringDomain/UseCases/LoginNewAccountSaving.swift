import Foundation

extension LoginNewAccountUseCase {
    func saveInactiveNewAccount(from stagedLoginURL: URL) async throws -> LoginNewAccountResult {
        let addResult = try await AddAccountUseCase(
            repository: repository,
            installer: installer,
            authReader: authReader,
            preferencesPort: preferencesPort,
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

        return LoginNewAccountResult(
            state: state,
            savedAlias: addResult.savedAlias,
            cleanupWarningReason: nil
        )
    }
}
