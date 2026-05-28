import Foundation
import CodexKeyringDomain

/// `CodexAppControlling` implementation that drives the macOS Codex desktop app
/// via `NSWorkspace`/`NSRunningApplication`.
///
/// Termination polling uses `Task.sleep`, so the controller does not block the
/// main actor while it waits for the previous Codex process to exit. The
/// controller also escalates a graceful `terminate()` request to
/// `forceTerminate()` when the app refuses to quit (for example, when an
/// unsaved-document sheet is up), so the relaunch step is only reached once
/// every prior Codex process is truly gone. Otherwise `NSWorkspace` will see
/// the half-dead old instance and activate it instead of starting fresh.
public struct NSWorkspaceCodexAppController: CodexAppControlling {
    public let codexAppURL: URL
    public let pollInterval: Duration
    public let pollAttempts: Int

    let environment: CodexAppEnvironment
    let log = CodexKeyringLog.makeAppLogger(.codexApp)

    public init(
        codexBundleIdentifier: String? = "com.openai.codex",
        codexAppURL: URL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
        pollInterval: Duration = .milliseconds(200),
        pollAttempts: Int = 75
    ) {
        self.init(
            environment: NSWorkspaceEnvironment(
                bundleIdentifier: codexBundleIdentifier,
                appURL: codexAppURL
            ),
            codexAppURL: codexAppURL,
            pollInterval: pollInterval,
            pollAttempts: pollAttempts
        )
    }

    public init(
        environment: CodexAppEnvironment,
        codexAppURL: URL,
        pollInterval: Duration = .milliseconds(200),
        pollAttempts: Int = 75
    ) {
        self.environment = environment
        self.codexAppURL = codexAppURL
        self.pollInterval = pollInterval
        self.pollAttempts = pollAttempts
    }

    public var isRunning: Bool {
        !environment.runningCodexApps().isEmpty
    }
}
