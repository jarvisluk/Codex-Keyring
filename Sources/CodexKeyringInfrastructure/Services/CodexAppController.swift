import AppKit
import Foundation
import os
import CodexKeyringDomain

/// `CodexAppControlling` implementation that drives the macOS Codex desktop app
/// via `NSWorkspace`/`NSRunningApplication`.
///
/// Termination polling uses `Task.sleep`, so the controller does not block the
/// main actor while it waits for the previous Codex process to exit.
public struct NSWorkspaceCodexAppController: CodexAppControlling {
    public let codexBundleIdentifier: String?
    public let codexAppURL: URL
    public let pollInterval: Duration
    public let pollAttempts: Int

    private let log = CodexKeyringLog.make(.codexApp)

    public init(
        codexBundleIdentifier: String? = "com.openai.codex",
        codexAppURL: URL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
        pollInterval: Duration = .milliseconds(150),
        pollAttempts: Int = 30
    ) {
        self.codexBundleIdentifier = codexBundleIdentifier
        self.codexAppURL = codexAppURL
        self.pollInterval = pollInterval
        self.pollAttempts = pollAttempts
    }

    public var isRunning: Bool {
        !runningCodexApplications().isEmpty
    }

    public func restartIfRunning() async throws -> CodexAppRestartOutcome {
        let running = runningCodexApplications()
        guard !running.isEmpty else {
            log.debug("codex app not running; no restart required")
            return .wasNotRunning
        }

        for app in running { app.terminate() }

        for _ in 0..<pollAttempts {
            if runningCodexApplications().isEmpty { break }
            try? await Task.sleep(for: pollInterval)
        }

        guard FileManager.default.fileExists(atPath: codexAppURL.path) else {
            log.warning("codex app bundle missing at \(self.codexAppURL.path, privacy: .public)")
            return .bundleMissing(path: codexAppURL.path)
        }

        try await launchCodexApp()
        log.info("codex app relaunched")
        return .relaunched
    }

    @MainActor
    private func launchCodexApp() async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: codexAppURL, configuration: configuration)
        } catch {
            throw CodexKeyringError.codexAppRelaunchFailed(reason: error.localizedDescription)
        }
    }

    private func runningCodexApplications() -> [NSRunningApplication] {
        let apps = NSWorkspace.shared.runningApplications
        if let bundleID = codexBundleIdentifier {
            let matched = apps.filter { $0.bundleIdentifier == bundleID }
            if !matched.isEmpty { return matched }
        }
        return apps.filter { $0.bundleURL?.lastPathComponent == codexAppURL.lastPathComponent }
    }
}

/// Legacy enum-style facade preserved for now so existing callers continue to
/// compile. Internally delegates to ``NSWorkspaceCodexAppController``.
public enum CodexAppController {
    public static var isCodexAppRunning: Bool {
        NSWorkspaceCodexAppController().isRunning
    }

    public static func restartCodexAppIfRunning() throws -> String {
        let controller = NSWorkspaceCodexAppController()
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var capturedOutcome: Result<CodexAppRestartOutcome, Error> = .failure(
            CodexKeyringError.codexAppRelaunchFailed(reason: "Operation cancelled.")
        )
        Task {
            do {
                let outcome = try await controller.restartIfRunning()
                capturedOutcome = .success(outcome)
            } catch {
                capturedOutcome = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        switch capturedOutcome {
        case .success(let outcome):
            return Self.message(for: outcome, bundlePath: controller.codexAppURL.path)
        case .failure(let error):
            throw error
        }
    }

    private static func message(for outcome: CodexAppRestartOutcome, bundlePath: String) -> String {
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
