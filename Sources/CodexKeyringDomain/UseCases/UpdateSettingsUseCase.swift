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

    public func setQuotaRefreshIntervalMinutes(_ value: Int) async throws -> AppSettings {
        try await mutate { $0.quotaRefreshIntervalMinutes = AppSettings.normalizedQuotaRefreshInterval(value) }
    }

    public func setLaunchAtLogin(_ value: Bool) async throws -> AppSettings {
        try await mutate { $0.launchAtLogin = value }
    }

    public func setPreserveAgentPreferencesPerAccount(_ value: Bool) async throws -> AppSettings {
        try await mutate { $0.preserveAgentPreferencesPerAccount = value }
    }

    private func mutate(_ change: (inout AppSettings) -> Void) async throws -> AppSettings {
        var manifest = try await repository.load()
        let original = manifest.settings
        change(&manifest.settings)
        guard manifest.settings != original else {
            return manifest.settings
        }
        try await repository.save(manifest)
        return manifest.settings
    }
}
