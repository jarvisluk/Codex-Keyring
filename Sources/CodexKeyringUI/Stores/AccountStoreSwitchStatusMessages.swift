import CodexKeyringDomain

extension AccountStoreStatusMessages {
    static func switchAccount(
        result: SwitchAccountResult,
        restartWasRequested: Bool
    ) -> String {
        let base: String
        if let restartFailureReason = result.restartFailureReason {
            let switchedPrefix = result.wasAlreadyActive
                ? "\(result.switchedAlias) was already the active Codex auth"
                : "Switched Codex CLI auth to \(result.switchedAlias)"
            base = "\(switchedPrefix), but Codex App could not be restarted: \(restartFailureReason)"
        } else if let restartOutcome = result.restartOutcome {
            base = restartOutcomeMessage(restartOutcome)
        } else if result.wasAlreadyActive {
            base = "\(result.switchedAlias) was already the active Codex auth."
        } else if restartWasRequested {
            base = "Switched Codex CLI auth to \(result.switchedAlias)."
        } else {
            base = "Switched Codex CLI auth to \(result.switchedAlias). Restart Codex App if it was already open."
        }

        var message = base
        if result.appliedAgentPreferences {
            message += " Restored saved agent settings for this account."
        }
        if let warning = result.agentPreferencesWarningReason {
            message += " Agent settings could not be fully updated: \(warning)"
        }
        if let warning = result.projectArrangementWarningReason {
            message += " Codex project list layout could not be preserved: \(warning)"
        }
        return message
    }

    private static func restartOutcomeMessage(_ outcome: CodexAppRestartOutcome) -> String {
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
