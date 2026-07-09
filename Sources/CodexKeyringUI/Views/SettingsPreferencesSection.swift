import SwiftUI

struct SettingsPreferencesSection: View {
    @EnvironmentObject private var store: AccountStore

    private var presentation: SettingsPreferencesPresentation {
        SettingsPreferencesPresentation(
            restartCodexAppAfterSwitch: store.settings.restartCodexAppAfterSwitch,
            quotaRefreshIntervalMinutes: store.settings.quotaRefreshIntervalMinutes,
            canToggleLaunchAtLogin: store.canSetLaunchAtLogin(to: !store.settings.launchAtLogin),
            canToggleShowDockIcon: store.canSetShowDockIcon(to: !store.settings.showDockIcon),
            canToggleRestartCodexAppAfterSwitch: store.canSetRestartCodexAppAfterSwitch(
                to: !store.settings.restartCodexAppAfterSwitch
            ),
            canTogglePreserveAgentPreferencesPerAccount: store.canSetPreserveAgentPreferencesPerAccount(
                to: !store.settings.preserveAgentPreferencesPerAccount
            ),
            canToggleAllowNetworkQuotaAPIs: store.canSetAllowNetworkQuotaAPIs(
                to: !store.settings.allowNetworkQuotaAPIs
            ),
            canEditQuotaRefreshInterval: store.canEditQuotaRefreshInterval
        )
    }

    var body: some View {
        SettingsSection("Preferences") {
            launchAtLoginToggle
            showDockIconToggle
            restartCodexAppToggle
            preserveAgentPreferencesToggle
            SettingsQuotaAPIControls(presentation: presentation.quotaAPI)
        }
    }

    private var launchAtLoginToggle: some View {
        Toggle("Launch at login", isOn: Binding(
            get: { store.settings.launchAtLogin },
            set: { store.setLaunchAtLogin($0) }
        ))
        .disabled(!presentation.canToggleLaunchAtLogin)
    }

    private var showDockIconToggle: some View {
        Toggle("Show Dock icon", isOn: Binding(
            get: { store.settings.showDockIcon },
            set: { store.setShowDockIcon($0) }
        ))
        .disabled(!presentation.canToggleShowDockIcon)
    }

    private var restartCodexAppToggle: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.note) {
            Toggle("Restart Codex App after switching accounts", isOn: Binding(
                get: { store.settings.restartCodexAppAfterSwitch },
                set: { store.setRestartCodexAppAfterSwitch($0) }
            ))
            .disabled(!presentation.canToggleRestartCodexAppAfterSwitch)

            SettingsNote(presentation.restartCodexAppNote)
                .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)
        }
    }

    private var preserveAgentPreferencesToggle: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.note) {
            Toggle("Remember per-account agent settings", isOn: Binding(
                get: { store.settings.preserveAgentPreferencesPerAccount },
                set: { store.setPreserveAgentPreferencesPerAccount($0) }
            ))
            .disabled(!presentation.canTogglePreserveAgentPreferencesPerAccount)

            SettingsNote(presentation.agentPreferencesNote)
                .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)
        }
    }
}
