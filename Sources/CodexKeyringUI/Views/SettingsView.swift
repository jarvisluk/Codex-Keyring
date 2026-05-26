import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @EnvironmentObject private var store: AccountStore

    public init() {}

    public var body: some View {
        Form {
            Toggle("Restart Codex App after switching", isOn: Binding(
                get: { store.settings.restartCodexAppAfterSwitch },
                set: { store.setRestartCodexAppAfterSwitch($0) }
            ))

            Toggle("Launch at login", isOn: Binding(
                get: { store.settings.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .disabled(!store.isLaunchAtLoginSupported)

            Toggle("Allow network quota/account API calls", isOn: Binding(
                get: { store.settings.allowNetworkQuotaAPIs },
                set: { store.setAllowNetworkQuotaAPIs($0) }
            ))
            .disabled(true)

            Text("Network quota APIs are intentionally disabled in this first version. Account switching works only with local Codex auth files.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            LabeledContent("Codex auth") {
                Text(store.storageLocations.codexAuthPath)
                    .textSelection(.enabled)
            }

            LabeledContent("App data") {
                Text(store.storageLocations.applicationSupportPath)
                    .textSelection(.enabled)
            }

            Divider()

            logsSection
        }
        .padding(24)
        .frame(width: 560)
    }

    @ViewBuilder
    private var logsSection: some View {
        LabeledContent("Logs") {
            Text(store.storageLocations.logsDirectoryPath)
                .textSelection(.enabled)
        }

        HStack(spacing: 12) {
            Button {
                exportLogs()
            } label: {
                Label("Export Logs…", systemImage: "square.and.arrow.up")
            }
            .disabled(!store.isLoggingAvailable)
            .help("Save the rolling log files into a single text file for sharing.")

            Button {
                revealLogsInFinder()
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .help("Open the Logs folder in Finder.")
        }

        Text("Logs include account-switching activity and errors. They never include the contents of `auth.json`.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.title = "Export Codex Keyring Logs"
        panel.message = "Choose where to save the combined log file."
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = Self.defaultExportFileName()
        if panel.runModal() == .OK, let url = panel.url {
            store.exportLogs(to: url)
        }
    }

    private func revealLogsInFinder() {
        let directory = store.logsDirectoryURL
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let logFile = store.currentLogFileURL
        if FileManager.default.fileExists(atPath: logFile.path) {
            NSWorkspace.shared.activateFileViewerSelecting([logFile])
        } else {
            NSWorkspace.shared.open(directory)
        }
    }

    private static func defaultExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "codex-keyring-\(formatter.string(from: Date())).log.txt"
    }
}
