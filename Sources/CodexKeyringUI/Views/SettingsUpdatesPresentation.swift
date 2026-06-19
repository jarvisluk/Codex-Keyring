struct SettingsUpdatesPresentation: Equatable {
    let canCheckForUpdates: Bool
    let canToggleAutomaticChecks: Bool
    let canToggleAutomaticDownloads: Bool
    let note: String

    init(
        isConfigured: Bool,
        canCheckForUpdates: Bool,
        isAutomaticCheckEnabled: Bool,
        canAutomaticallyDownloadUpdates: Bool,
        isAutomaticDownloadEnabled: Bool
    ) {
        self.canCheckForUpdates = isConfigured && canCheckForUpdates
        canToggleAutomaticChecks = isConfigured
        canToggleAutomaticDownloads = isConfigured
            && isAutomaticCheckEnabled
            && canAutomaticallyDownloadUpdates

        if isConfigured {
            if !isAutomaticCheckEnabled {
                note = "Automatic update checks are off. Use Check Now when you want to look for a release."
            } else if isAutomaticDownloadEnabled {
                note = "Automatic updates are enabled. Manual checks remain available."
            } else {
                note = "Automatic checks are enabled. New releases will ask before installing."
            }
        } else {
            note = "Update checks are available in release builds configured with a Sparkle appcast."
        }
    }
}
