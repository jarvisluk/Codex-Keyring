import CodexKeyringDomain

struct AccountStoreSettingsUpdate: Sendable {
    let settings: AppSettings
    let statusMessage: String
    let logMessage: String
}

extension AccountStore {
    func runPersistedSettingsUpdate(
        statusMessage: @escaping @MainActor @Sendable (AppSettings) -> String,
        logMessage: @escaping @MainActor @Sendable (AppSettings) -> String,
        onFailure: (@MainActor @Sendable (Error) -> Void)? = nil,
        _ persistSettings: @escaping @MainActor @Sendable () async throws -> AppSettings
    ) {
        runSettingsUpdate(onFailure: onFailure) {
            let settings = try await persistSettings()
            return AccountStoreSettingsUpdate(
                settings: settings,
                statusMessage: statusMessage(settings),
                logMessage: logMessage(settings)
            )
        }
    }

    func runSettingsUpdate(
        onFailure: (@MainActor @Sendable (Error) -> Void)? = nil,
        _ makeUpdate: @escaping @MainActor @Sendable () async throws -> AccountStoreSettingsUpdate
    ) {
        run {
            let update = try await makeUpdate()
            self.finishSettingsUpdate(update)
        } onFailure: { error in
            onFailure?(error)
        }
    }

    func finishSettingsUpdate(_ update: AccountStoreSettingsUpdate) {
        apply(update.settings)
        self.statusMessage = update.statusMessage
        logService?.info(update.logMessage)
    }
}
