import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CodexKeyringDomain

public struct SettingsView: View {
    @EnvironmentObject private var store: AccountStore

    public init() {}

    private var settingsActionIndent: CGFloat {
        KeyringStyle.Layout.settingsLocationLabelWidth
            + KeyringStyle.Spacing.settingsActionIndentOffset
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.settingsSection) {
                preferencesSection
                Divider()
                locationsSection
                Divider()
                logsSection
            }
            .padding(.horizontal, KeyringStyle.Spacing.settingsHorizontalPadding)
            .padding(.vertical, KeyringStyle.Spacing.settingsVerticalPadding)
        }
        .frame(
            width: KeyringStyle.Layout.settingsWindowWidth,
            height: KeyringStyle.Layout.settingsWindowHeight
        )
        .accountStoreFailureAlert(store)
    }

    private var preferencesSection: some View {
        SettingsSection("Preferences") {
            Toggle("Launch at login", isOn: Binding(
                get: { store.settings.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .disabled(!store.canSetLaunchAtLogin(to: !store.settings.launchAtLogin))

            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.note) {
                Toggle("Restart Codex App after switching accounts", isOn: Binding(
                    get: { store.settings.restartCodexAppAfterSwitch },
                    set: { store.setRestartCodexAppAfterSwitch($0) }
                ))
                .disabled(!store.canSetRestartCodexAppAfterSwitch(to: !store.settings.restartCodexAppAfterSwitch))

                SettingsNote("Leave this on when you want Codex App to reload auth immediately. Per-account agent settings are restored only during a restart.")
                    .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)
            }

            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.note) {
                Toggle("Remember per-account agent settings", isOn: Binding(
                    get: { store.settings.preserveAgentPreferencesPerAccount },
                    set: { store.setPreserveAgentPreferencesPerAccount($0) }
                ))
                .disabled(!store.canSetPreserveAgentPreferencesPerAccount(to: !store.settings.preserveAgentPreferencesPerAccount))

                SettingsNote(agentPreferencesNote)
                    .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)
            }

            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.compact) {
                Toggle("Allow network quota/account API calls", isOn: Binding(
                    get: { store.settings.allowNetworkQuotaAPIs },
                    set: { store.setAllowNetworkQuotaAPIs($0) }
                ))
                .disabled(!store.canSetAllowNetworkQuotaAPIs(to: !store.settings.allowNetworkQuotaAPIs))

                HStack(alignment: .firstTextBaseline, spacing: KeyringStyle.Spacing.section) {
                    Text("Quota refresh interval")
                        .frame(width: KeyringStyle.Layout.settingsQuotaLabelWidth, alignment: .leading)

                    Picker("Quota refresh interval", selection: Binding(
                        get: { store.settings.quotaRefreshIntervalMinutes },
                        set: { store.setQuotaRefreshIntervalMinutes($0) }
                    )) {
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                    .labelsHidden()
                    .frame(width: KeyringStyle.Layout.settingsQuotaPickerWidth, alignment: .leading)
                }
                .disabled(!store.canEditQuotaRefreshInterval)
                .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)

                SettingsNote("When enabled, Codex Keyring checks saved ChatGPT/Codex accounts every \(store.settings.quotaRefreshIntervalMinutes) minutes and refreshes rotated OAuth tokens back into their local snapshots.")
                    .padding(.leading, KeyringStyle.Spacing.settingsControlTextIndent)
            }
        }
    }

    private var locationsSection: some View {
        SettingsSection("Locations") {
            Grid(
                alignment: .leading,
                horizontalSpacing: KeyringStyle.Grid.locationHorizontalSpacing,
                verticalSpacing: KeyringStyle.Grid.locationVerticalSpacing
            ) {
                locationRow("Codex auth", path: store.storageLocations.codexAuthPath, revealKind: .file)
                locationRow("App data", path: store.storageLocations.applicationSupportPath, revealKind: .directory)
                locationRow("Accounts", path: store.storageLocations.accountsDirectoryPath, revealKind: .directory)
                locationRow("Backups", path: store.storageLocations.backupsDirectoryPath, revealKind: .directory)
            }
        }
    }

    @ViewBuilder
    private var logsSection: some View {
        SettingsSection("Logs") {
            Grid(
                alignment: .leading,
                horizontalSpacing: KeyringStyle.Grid.locationHorizontalSpacing,
                verticalSpacing: KeyringStyle.Grid.locationVerticalSpacing
            ) {
                locationRow("Directory", path: store.storageLocations.logsDirectoryPath)
            }

            HStack(spacing: KeyringStyle.Spacing.section) {
                Button {
                    exportLogs()
                } label: {
                    Label(
                        store.isLogExportInProgress ? "Exporting Logs..." : "Export Logs...",
                        systemImage: store.isLogExportInProgress ? "hourglass" : "square.and.arrow.up"
                    )
                }
                .disabled(!store.canExportLogs)
                .help("Save the rolling log files into a single text file for sharing.")

                Button {
                    revealLogsInFinder()
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .help("Open the Logs folder in Finder.")
            }
            .padding(.leading, settingsActionIndent)

            SettingsNote("Logs include account-switching activity and errors. They never include the contents of `auth.json`.")
                .padding(.leading, settingsActionIndent)
        }
    }

    @ViewBuilder
    private func locationRow(_ title: String, path: String, revealKind: LocationKind? = nil) -> some View {
        GridRow {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: KeyringStyle.Layout.settingsLocationLabelWidth, alignment: .trailing)

            Text(path)
                .font(.callout.monospaced())
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(path)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let revealKind {
                Button {
                    revealLocation(path: path, kind: revealKind)
                } label: {
                    Label("Reveal", systemImage: revealKind.systemImage)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Reveal \(title) in Finder.")
            }
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
        guard prepareDirectoryForFinder(directory) else { return }

        let logFile = store.currentLogFileURL
        if FileManager.default.fileExists(atPath: logFile.path) {
            NSWorkspace.shared.activateFileViewerSelecting([logFile])
        } else {
            openDirectoryInFinder(directory)
        }
    }

    private func revealLocation(path: String, kind: LocationKind) {
        let url = URL(fileURLWithPath: path, isDirectory: kind == .directory)
        switch kind {
        case .directory:
            guard prepareDirectoryForFinder(url) else { return }
            openDirectoryInFinder(url)
        case .file:
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                guard prepareDirectoryForFinder(parent) else { return }
                openDirectoryInFinder(parent)
            }
        }
    }

    private func prepareDirectoryForFinder(_ directory: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return true
        } catch {
            reportFinderFailure("Could not prepare \(directory.path): \(error.localizedDescription)")
            return false
        }
    }

    private func openDirectoryInFinder(_ directory: URL) {
        guard NSWorkspace.shared.open(directory) else {
            reportFinderFailure("Could not open \(directory.path) in Finder")
            return
        }
    }

    private func reportFinderFailure(_ reason: String) {
        store.reportUserFacingError(CodexKeyringError.fileSystemFailure(reason: reason))
    }

    private static func defaultExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "codex-keyring-\(formatter.string(from: Date())).log.txt"
    }

    private var agentPreferencesNote: String {
        if store.settings.restartCodexAppAfterSwitch {
            return "When switching accounts, Codex Keyring restarts Codex App, captures the outgoing account's model, reasoning effort, approval/sandbox mode, and Full Access / Auto Review setting, and applies the incoming account's saved values while Codex App is stopped."
        }
        return "Per-account agent settings require Restart Codex App after switching accounts. Turn that on before switching when you want saved model, reasoning effort, approval/sandbox mode, and Full Access / Auto Review settings restored automatically."
    }
}

private enum LocationKind {
    case directory
    case file

    var systemImage: String {
        switch self {
        case .directory:
            return "folder"
        case .file:
            return "doc.text.magnifyingglass"
        }
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
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.section) {
            KeyringSectionHeader(title)

            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.contentGroup) {
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
