import CodexKeyringDomain

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
