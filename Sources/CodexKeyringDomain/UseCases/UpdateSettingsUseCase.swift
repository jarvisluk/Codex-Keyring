import Foundation

/// Persist a partial change to `AppSettings`.
public struct UpdateSettingsUseCase: Sendable {
    private let repository: AccountRepository

    public init(repository: AccountRepository) {
        self.repository = repository
    }

    public func setRestartCodexAppAfterSwitch(_ value: Bool) async throws -> AppSettings {
        try await mutate { $0.restartCodexAppAfterSwitch = value }
    }

    public func setAllowNetworkQuotaAPIs(_ value: Bool) async throws -> AppSettings {
        try await mutate { $0.allowNetworkQuotaAPIs = value }
    }

    public func setLaunchAtLogin(_ value: Bool) async throws -> AppSettings {
        try await mutate { $0.launchAtLogin = value }
    }

    private func mutate(_ change: (inout AppSettings) -> Void) async throws -> AppSettings {
        var manifest = try await repository.load()
        change(&manifest.settings)
        try await repository.save(manifest)
        return manifest.settings
    }
}
