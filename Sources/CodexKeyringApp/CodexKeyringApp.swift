import AppKit
import SwiftUI
import CodexKeyringUI
import CodexKeyringInfrastructure
import CodexKeyringDomain

@main
struct CodexKeyringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AccountStore

    init() {
        _store = StateObject(wrappedValue: Self.makeStore())
    }

    var body: some Scene {
        Window("Codex Keyring", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 920, minHeight: 600)
        }
        .defaultSize(width: 1040, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Accounts") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.isRefreshInProgress)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            Image(systemName: store.activeAccount == nil ? "person.crop.circle.badge.questionmark" : "person.crop.circle.badge.checkmark")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private extension CodexKeyringApp {
    @MainActor
    static func makeStore() -> AccountStore {
        try? AppPaths.ensureDirectories()
        CodexKeyringLog.bootstrapFileSink()
        let appLogger = CodexKeyringLog.makeAppLogger(.app)
        appLogger.info("Codex Keyring launching; logFile=\(AppPaths.currentLogFile.path)")

        let repository = FileSystemManifestRepository()
        let installer = LiveCodexAuthInstaller()
        let authReader = AuthFileParser()
        let agentPreferencesPort = LiveCodexAgentPreferencesPort()
        return AccountStore(
            repository: repository,
            installer: installer,
            authReader: authReader,
            appController: NSWorkspaceCodexAppController(),
            launchAtLoginController: SMAppServiceLaunchAtLogin(),
            loginService: ChatGPTOAuthLoginService(),
            agentPreferencesPort: agentPreferencesPort,
            storageLocations: AccountStorageLocations(
                codexAuthPath: AppPaths.codexAuthFile.path,
                applicationSupportPath: AppPaths.applicationSupportDirectory.path,
                accountsDirectoryPath: AppPaths.accountsDirectory.path,
                backupsDirectoryPath: AppPaths.backupsDirectory.path,
                logsDirectoryPath: AppPaths.logsDirectory.path,
                currentLogFilePath: AppPaths.currentLogFile.path
            ),
            openAuthURL: { url in
                try await MainActor.run {
                    guard NSWorkspace.shared.open(url) else {
                        throw CodexKeyringError.codexLoginFailed(reason: "Could not open \(url.absoluteString).")
                    }
                }
            },
            logService: CodexKeyringLog.makeAppLogger(.store),
            liveAuthWatcher: LiveAuthFileWatcher()
        )
    }
}
