import Foundation
import CodexKeyringDomain

extension NSWorkspaceCodexAppController {
    func terminateRunningCodexApps(_ apps: [RunningCodexApp]) async throws {
        var refused: [pid_t: RunningCodexApp] = [:]
        for app in apps where !app.isTerminated {
            let accepted = app.terminate()
            if !accepted {
                log.warning("codex app pid \(app.processIdentifier) refused graceful terminate")
                refused[app.processIdentifier] = app
            }
        }

        if await waitForExit(of: apps) { return }

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
    func waitForExit(of apps: [RunningCodexApp]) async -> Bool {
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
