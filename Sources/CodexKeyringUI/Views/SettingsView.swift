import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var store: AccountStore
    @EnvironmentObject private var settingsPresentation: SettingsPresentationStore

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.settingsSection) {
                SettingsPreferencesSection()
                Divider()
                SettingsLocationsSection()
                Divider()
                SettingsCommandLineSection()
                Divider()
                SettingsLogsSection()
            }
            .padding(.horizontal, KeyringStyle.Spacing.settingsHorizontalPadding)
            .padding(.vertical, KeyringStyle.Spacing.settingsVerticalPadding)
        }
        .frame(
            width: KeyringStyle.Layout.settingsWindowWidth,
            height: KeyringStyle.Layout.settingsWindowHeight
        )
        .accountStoreFailureAlert(store)
        .onAppear {
            settingsPresentation.present()
        }
        .onDisappear {
            settingsPresentation.dismiss()
        }
    }
}
