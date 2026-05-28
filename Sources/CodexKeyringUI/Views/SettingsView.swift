import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var store: AccountStore
    private let onDismiss: (() -> Void)?

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let onDismiss {
                SettingsModalHeader(onDismiss: onDismiss)
                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: KeyringStyle.Spacing.settingsSection) {
                    SettingsPreferencesSection()
                    Divider()
                    SettingsLocationsSection()
                    Divider()
                    SettingsLogsSection()
                }
                .padding(.horizontal, KeyringStyle.Spacing.settingsHorizontalPadding)
                .padding(.vertical, KeyringStyle.Spacing.settingsVerticalPadding)
            }
        }
        .frame(
            width: KeyringStyle.Layout.settingsWindowWidth,
            height: KeyringStyle.Layout.settingsWindowHeight
        )
        .accountStoreFailureAlert(store)
    }
}
