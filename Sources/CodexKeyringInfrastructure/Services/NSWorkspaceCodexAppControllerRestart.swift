import Foundation
import CodexKeyringDomain

extension NSWorkspaceCodexAppController {
    public func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void = {}
    ) async throws -> CodexAppRestartOutcome {
        let initial = environment.runningCodexApps()
        guard !initial.isEmpty else {
            log.debug("codex app not running; no restart required")
            return .wasNotRunning
        }

        log.info("terminating \(initial.count) codex app process(es)")
        try await terminateRunningCodexApps(initial)
        try await runPreRelaunchHook(beforeRelaunch)

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

    private func runPreRelaunchHook(
        _ beforeRelaunch: @Sendable () async throws -> Void
    ) async throws {
        do {
            try await beforeRelaunch()
        } catch {
            throw CodexKeyringError.codexAppRelaunchFailed(
                reason: "Pre-relaunch hook failed: \(error.localizedDescription)"
            )
        }
    }
}
