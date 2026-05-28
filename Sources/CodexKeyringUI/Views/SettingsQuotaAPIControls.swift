import SwiftUI

struct SettingsQuotaAPIControls: View {
    @EnvironmentObject private var store: AccountStore

    let presentation: SettingsQuotaAPIPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.compact) {
            Toggle("Allow network quota/account API calls", isOn: Binding(
                get: { store.settings.allowNetworkQuotaAPIs },
                set: { store.setAllowNetworkQuotaAPIs($0) }
            ))
            .disabled(!presentation.canToggleAllowNetworkQuotaAPIs)

            quotaRefreshIntervalPicker

            SettingsNote(presentation.quotaRefreshNote)
                .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)
        }
    }

    private var quotaRefreshIntervalPicker: some View {
        HStack(alignment: .firstTextBaseline, spacing: KeyringStyle.Spacing.section) {
            Text("Quota refresh interval")
                .frame(width: KeyringStyle.Layout.settingsQuotaLabelWidth, alignment: .leading)

            Picker("Quota refresh interval", selection: Binding(
                get: { store.settings.quotaRefreshIntervalMinutes },
                set: { store.setQuotaRefreshIntervalMinutes($0) }
            )) {
                ForEach(presentation.intervalOptions) { option in
                    Text(option.title).tag(option.minutes)
                }
            }
            .labelsHidden()
            .frame(width: KeyringStyle.Layout.settingsQuotaPickerWidth, alignment: .leading)
        }
        .disabled(!presentation.canEditQuotaRefreshInterval)
        .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)
    }
}
