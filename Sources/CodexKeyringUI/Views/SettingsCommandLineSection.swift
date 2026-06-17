import SwiftUI

struct SettingsCommandLineSection: View {
    @EnvironmentObject private var store: AccountStore
    @State private var commandLineMessage: String?

    private var presentation: SettingsCommandLinePresentation {
        SettingsCommandLinePresentation()
    }

    var body: some View {
        SettingsSection("Command Line") {
            HStack(alignment: .firstTextBaseline, spacing: KeyringStyle.Spacing.section) {
                Text("Try")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: KeyringStyle.Layout.settingsLocationLabelWidth, alignment: .trailing)

                Text(presentation.command)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .firstTextBaseline, spacing: KeyringStyle.Spacing.section) {
                Text("Manage")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: KeyringStyle.Layout.settingsLocationLabelWidth, alignment: .trailing)

                Button {
                    installCommand()
                } label: {
                    Label(presentation.installTitle, systemImage: "arrow.down.circle")
                }
                .help("Install ckr to \(presentation.installDestinationPath).")

                Button {
                    uninstallCommand()
                } label: {
                    Label(presentation.uninstallTitle, systemImage: "trash")
                }
                .help("Remove ckr from \(presentation.installDestinationPath).")

                Text(presentation.installDestinationPath)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(presentation.installDestinationPath)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsNote(commandLineMessage ?? presentation.note)
                .padding(.leading, KeyringStyle.Layout.settingsLocationLabelWidth + KeyringStyle.Spacing.section)
        }
    }

    private func installCommand() {
        do {
            let result = try CommandLineInstaller.installFromBundle()
            commandLineMessage = "Installed ckr to \(result.destinationPath)."
        } catch {
            commandLineMessage = nil
            store.reportUserFacingError(error)
        }
    }

    private func uninstallCommand() {
        do {
            let result = try CommandLineInstaller.uninstall()
            if result.didRemove {
                commandLineMessage = "Removed ckr from \(result.destinationPath)."
            } else {
                commandLineMessage = "ckr is not installed at \(result.destinationPath)."
            }
        } catch {
            commandLineMessage = nil
            store.reportUserFacingError(error)
        }
    }
}
