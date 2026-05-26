import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @EnvironmentObject private var store: AccountStore
    private static let controlTextIndent: CGFloat = 26
    private static let locationLabelWidth: CGFloat = 104

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                preferencesSection
                Divider()
                locationsSection
                Divider()
                logsSection
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .frame(width: 700, height: 560)
    }

    private var preferencesSection: some View {
        SettingsSection("Preferences") {
            Toggle("Launch at login", isOn: Binding(
                get: { store.settings.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .disabled(!store.isLaunchAtLoginSupported)

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Remember per-account agent settings", isOn: Binding(
                    get: { store.settings.preserveAgentPreferencesPerAccount },
                    set: { store.setPreserveAgentPreferencesPerAccount($0) }
                ))

                SettingsNote("When switching accounts, Codex Keyring restarts Codex App, captures the outgoing account's model, reasoning effort, approval/sandbox mode, and Full Access / Auto Review setting, and applies the incoming account's saved values while Codex App is stopped.")
                    .padding(.leading, Self.controlTextIndent)
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Allow network quota/account API calls", isOn: Binding(
                    get: { store.settings.allowNetworkQuotaAPIs },
                    set: { store.setAllowNetworkQuotaAPIs($0) }
                ))

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Quota refresh interval")
                        .frame(width: 148, alignment: .leading)

                    Picker("Quota refresh interval", selection: Binding(
                        get: { store.settings.quotaRefreshIntervalMinutes },
                        set: { store.setQuotaRefreshIntervalMinutes($0) }
                    )) {
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                    .labelsHidden()
                    .frame(width: 150, alignment: .leading)
                }
                .disabled(!store.settings.allowNetworkQuotaAPIs)
                .padding(.leading, Self.controlTextIndent)

                SettingsNote("When enabled, Codex Keyring checks saved ChatGPT/Codex accounts every \(store.settings.quotaRefreshIntervalMinutes) minutes and refreshes rotated OAuth tokens back into their local snapshots.")
                    .padding(.leading, Self.controlTextIndent)
            }
        }
    }

    private var locationsSection: some View {
        SettingsSection("Locations") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                locationRow("Codex auth", path: store.storageLocations.codexAuthPath)
                locationRow("App data", path: store.storageLocations.applicationSupportPath)
            }
        }
    }

    @ViewBuilder
    private var logsSection: some View {
        SettingsSection("Logs") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                locationRow("Directory", path: store.storageLocations.logsDirectoryPath)
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
            .padding(.leading, Self.locationLabelWidth + 16)

            SettingsNote("Logs include account-switching activity and errors. They never include the contents of `auth.json`.")
                .padding(.leading, Self.locationLabelWidth + 16)
        }
    }

    @ViewBuilder
    private func locationRow(_ title: String, path: String) -> some View {
        GridRow {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: Self.locationLabelWidth, alignment: .trailing)

            Text(path)
                .font(.callout.monospaced())
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(path)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
