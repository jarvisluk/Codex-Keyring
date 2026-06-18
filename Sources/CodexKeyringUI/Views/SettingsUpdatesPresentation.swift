struct SettingsUpdatesPresentation: Equatable {
    let canCheckForUpdates: Bool
    let canToggleAutomaticChecks: Bool
    let note: String

    init(
        isConfigured: Bool,
        canCheckForUpdates: Bool,
        isAutomaticCheckEnabled: Bool
    ) {
        self.canCheckForUpdates = isConfigured && canCheckForUpdates
        canToggleAutomaticChecks = isConfigured
        if isConfigured {
            note = isAutomaticCheckEnabled
                ? "Automatic update checks are enabled. Manual checks remain available."
                : "Automatic update checks are off. Use Check Now when you want to look for a release."
        } else {
            note = "Update checks are available in release builds configured with a Sparkle appcast."
        }
    }
}
