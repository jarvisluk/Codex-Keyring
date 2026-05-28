import SwiftUI

struct SettingsLogsSection: View {
    @EnvironmentObject private var store: AccountStore

    private var actionIndent: CGFloat {
        KeyringStyle.Layout.settingsLocationLabelWidth
            + KeyringStyle.Spacing.settingsActionIndentOffset
    }

    private var presentation: SettingsLogsPresentation {
        SettingsLogsPresentation(
            isExportInProgress: store.isLogExportInProgress,
            canExportLogs: store.canExportLogs
        )
    }

    var body: some View {
        SettingsSection("Logs") {
            Grid(
                alignment: .leading,
                horizontalSpacing: KeyringStyle.Grid.locationHorizontalSpacing,
                verticalSpacing: KeyringStyle.Grid.locationVerticalSpacing
            ) {
                SettingsLocationRow("Directory", path: store.storageLocations.logsDirectoryPath)
            }

            HStack(spacing: KeyringStyle.Spacing.section) {
                Button {
                    exportLogs()
                } label: {
                    Label(
                        presentation.exportTitle,
                        systemImage: presentation.exportSystemImage
                    )
                }
                .disabled(!presentation.canExportLogs)
                .help("Save the rolling log files into a single text file for sharing.")

                Button {
                    revealLogsInFinder()
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .help("Open the Logs folder in Finder.")
            }
            .padding(.leading, actionIndent)

            SettingsNote("Logs include account-switching activity and errors. They never include the contents of `auth.json`.")
                .padding(.leading, actionIndent)
        }
    }

    private func exportLogs() {
        if let url = SettingsFileActions.chooseLogExportDestination() {
            store.exportLogs(to: url)
        }
    }

    private func revealLogsInFinder() {
        do {
            try SettingsFileActions.revealLogs(
                directory: store.logsDirectoryURL,
                currentLogFile: store.currentLogFileURL
            )
        } catch {
            store.reportUserFacingError(error)
        }
    }
}
