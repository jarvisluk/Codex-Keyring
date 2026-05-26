import AppKit
import Foundation
import CodexKeyringDomain

/// Abstraction over a running app instance so we can substitute
/// `NSRunningApplication` (which has no public initializer) in unit tests.
public protocol RunningCodexApp: Sendable {
    var processIdentifier: pid_t { get }
    var isTerminated: Bool { get }
    @discardableResult func terminate() -> Bool
    @discardableResult func forceTerminate() -> Bool
}

extension NSRunningApplication: RunningCodexApp {}

/// Provides the I/O primitives used by ``NSWorkspaceCodexAppController``.
/// All members are async to make swapping in deterministic test doubles easy.
public protocol CodexAppEnvironment: Sendable {
    func runningCodexApps() -> [RunningCodexApp]
    func bundleExists(at url: URL) -> Bool
    func launchApp(at url: URL) async throws
}

/// `CodexAppControlling` implementation that drives the macOS Codex desktop app
/// via `NSWorkspace`/`NSRunningApplication`.
///
/// Termination polling uses `Task.sleep`, so the controller does not block the
/// main actor while it waits for the previous Codex process to exit. The
/// controller also escalates a graceful `terminate()` request to
/// `forceTerminate()` when the app refuses to quit (for example, when an
/// unsaved-document sheet is up), so the relaunch step is only reached once
/// every prior Codex process is truly gone — otherwise `NSWorkspace` will see
/// the half-dead old instance and "activate" it instead of starting fresh.
public struct NSWorkspaceCodexAppController: CodexAppControlling {
    public let codexAppURL: URL
    public let pollInterval: Duration
    public let pollAttempts: Int

    private let environment: CodexAppEnvironment
    private let log = CodexKeyringLog.makeAppLogger(.codexApp)

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

    public func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void = {}
    ) async throws -> CodexAppRestartOutcome {
        let initial = environment.runningCodexApps()
        guard !initial.isEmpty else {
            log.debug("codex app not running; no restart required")
            return .wasNotRunning
        }

        log.info("terminating \(initial.count) codex app process(es)")
        try await terminate(initial)

        // Run the caller-supplied hook (e.g. rewriting Codex state files)
        // BEFORE the bundle check so the hook still runs even when the
        // bundle has been moved/removed since launch.
        do {
            try await beforeRelaunch()
        } catch {
            throw CodexKeyringError.codexAppRelaunchFailed(reason: "Pre-relaunch hook failed: \(error.localizedDescription)")
        }

        guard environment.bundleExists(at: codexAppURL) else {
            log.warning("codex app bundle missing at \(self.codexAppURL.path)")
            return .bundleMissing(path: codexAppURL.path)
        }

        do {
            try await environment.launchApp(at: codexAppURL)
        } catch {
            throw CodexKeyringError.codexAppRelaunchFailed(reason: error.localizedDescription)
        }
        log.info("codex app relaunched")
        return .relaunched
    }

    private func terminate(_ apps: [RunningCodexApp]) async throws {
        var refused: [pid_t: RunningCodexApp] = [:]
        for app in apps where !app.isTerminated {
            let accepted = app.terminate()
            if !accepted {
                log.warning("codex app pid \(app.processIdentifier) refused graceful terminate")
                refused[app.processIdentifier] = app
            }
        }

        if await waitForExit(of: apps) { return }

        // Combine processes that refused with anything still alive in the workspace.
        var stragglers = refused
        for app in environment.runningCodexApps() where !app.isTerminated {
            stragglers[app.processIdentifier] = app
        }

        guard !stragglers.isEmpty else { return }

        log.warning("codex app still running after graceful terminate; escalating to forceTerminate")
        for app in stragglers.values {
            _ = app.forceTerminate()
        }

        if await waitForExit(of: Array(stragglers.values)) { return }

        let pids = stragglers.keys.map(String.init).joined(separator: ", ")
        throw CodexKeyringError.codexAppRelaunchFailed(
            reason: "Codex app processes (\(pids)) did not exit after forceTerminate."
        )
    }

    /// Polls until every supplied app reports `isTerminated` AND no fresh Codex
    /// process is observed via the environment. Returns `true` if both
    /// conditions hold inside the poll budget.
    private func waitForExit(of apps: [RunningCodexApp]) async -> Bool {
        for _ in 0..<pollAttempts {
            let allOriginalExited = apps.allSatisfy { $0.isTerminated }
            let noRemainingCodex = environment.runningCodexApps().isEmpty
            if allOriginalExited && noRemainingCodex {
                return true
            }
            try? await Task.sleep(for: pollInterval)
        }
        return false
    }
}

/// Default ``CodexAppEnvironment`` backed by `NSWorkspace`/`NSRunningApplication`.
public struct NSWorkspaceEnvironment: CodexAppEnvironment {
    public let bundleIdentifier: String?
    public let appURL: URL

    public init(bundleIdentifier: String?, appURL: URL) {
        self.bundleIdentifier = bundleIdentifier
        self.appURL = appURL
    }

    public func runningCodexApps() -> [RunningCodexApp] {
        let apps = NSWorkspace.shared.runningApplications
        if let bundleID = bundleIdentifier {
            let matched = apps.filter { $0.bundleIdentifier == bundleID }
            if !matched.isEmpty { return matched }
        }
        return apps.filter { $0.bundleURL?.lastPathComponent == appURL.lastPathComponent }
    }

    public func bundleExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    @MainActor
    public func launchApp(at url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}

/// Compatibility facade for callers that still want a message string instead
/// of the typed ``CodexAppRestartOutcome``.
public enum CodexAppController {
    public static var isCodexAppRunning: Bool {
        NSWorkspaceCodexAppController().isRunning
    }

    public static func restartCodexAppIfRunning() async throws -> String {
        let controller = NSWorkspaceCodexAppController()
        let outcome = try await controller.restartIfRunning()
        return Self.message(for: outcome)
    }

    private static func message(for outcome: CodexAppRestartOutcome) -> String {
        switch outcome {
        case .wasNotRunning:
            return "Codex App was not running; Codex CLI will use the switched account immediately."
        case .relaunched:
            return "Codex App was restarted so it can reload the switched auth state."
        case .bundleMissing(let path):
            return "Codex App was quit, but \(path) was not found for relaunch."
        }
    }
}
