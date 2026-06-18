import SwiftUI

struct SettingsUpdatesSection: View {
    @EnvironmentObject private var softwareUpdates: SoftwareUpdateController

    private var presentation: SettingsUpdatesPresentation {
        SettingsUpdatesPresentation(
            isConfigured: softwareUpdates.isConfigured,
            canCheckForUpdates: softwareUpdates.canCheckForUpdates,
            isAutomaticCheckEnabled: softwareUpdates.isAutomaticCheckEnabled,
            canAutomaticallyDownloadUpdates: softwareUpdates.canAutomaticallyDownloadUpdates,
            isAutomaticDownloadEnabled: softwareUpdates.isAutomaticDownloadEnabled
        )
    }

    var body: some View {
        SettingsSection("Updates") {
            HStack(alignment: .firstTextBaseline, spacing: KeyringStyle.Spacing.section) {
                Text("Check")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: KeyringStyle.Layout.settingsLocationLabelWidth, alignment: .trailing)

                Button {
                    softwareUpdates.checkForUpdates()
                } label: {
                    Label("Check Now", systemImage: "arrow.clockwise")
                }
                .disabled(!presentation.canCheckForUpdates)
                .help("Check for updates now.")
            }

            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.note) {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { softwareUpdates.isAutomaticCheckEnabled },
                    set: { softwareUpdates.setAutomaticCheckEnabled($0) }
                ))
                .disabled(!presentation.canToggleAutomaticChecks)

                Toggle("Automatically download and install updates", isOn: Binding(
                    get: { softwareUpdates.isAutomaticDownloadEnabled },
                    set: { softwareUpdates.setAutomaticDownloadEnabled($0) }
                ))
                .disabled(!presentation.canToggleAutomaticDownloads)

                SettingsNote(presentation.note)
                    .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)
            }
        }
    }
}
