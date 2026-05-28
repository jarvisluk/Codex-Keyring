import Foundation

public struct RefreshAccountQuotasUseCase: Sendable {
    let repository: AccountRepository
    let installer: CodexAuthInstalling
    let query: AccountQuotaQuerying
    let clock: Clock

    public init(
        repository: AccountRepository,
        installer: CodexAuthInstalling,
        query: AccountQuotaQuerying,
        clock: Clock = SystemClock()
    ) {
        self.repository = repository
        self.installer = installer
        self.query = query
        self.clock = clock
    }
}
