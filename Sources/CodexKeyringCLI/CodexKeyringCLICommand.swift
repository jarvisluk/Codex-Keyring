import Foundation

enum CodexKeyringCLICommand: Equatable {
    case help
    case list(json: Bool)
    case status(json: Bool)
    case paths(json: Bool)
    case saveCurrent(alias: String?, json: Bool)
    case importAuth(path: String, alias: String?, json: Bool)
    case switchAccount(selector: String, restart: RestartPreference, json: Bool)
    case rename(selector: String, alias: String, json: Bool)
    case remove(selector: String, confirmed: Bool, json: Bool)
    case settingsGet(json: Bool)
    case settingsSet(key: String, value: String, json: Bool)
    case quotaRefresh(json: Bool)

    enum RestartPreference: Equatable, Sendable {
        case settingsDefault
        case restart
        case noRestart
    }
}

enum CodexKeyringCLIParseError: LocalizedError, Equatable {
    case usage(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message):
            return message
        }
    }
}

struct CodexKeyringCLIParser: Sendable {
    func parse(_ arguments: [String]) throws -> CodexKeyringCLICommand {
        var tokens = arguments
        if tokens.isEmpty {
            return .help
        }

        if removeFlag("--help", from: &tokens) || removeFlag("-h", from: &tokens) {
            return .help
        }
        let json = removeFlag("--json", from: &tokens)

        guard let command = tokens.first else {
            return .help
        }
        tokens.removeFirst()

        switch command {
        case "list":
            try requireNoExtra(tokens)
            return .list(json: json)
        case "status":
            try requireNoExtra(tokens)
            return .status(json: json)
        case "paths":
            try requireNoExtra(tokens)
            return .paths(json: json)
        case "save-current":
            let alias = try removeValue("--alias", from: &tokens)
            try requireNoExtra(tokens)
            return .saveCurrent(alias: alias, json: json)
        case "import":
            let alias = try removeValue("--alias", from: &tokens)
            guard let path = tokens.first else {
                throw CodexKeyringCLIParseError.usage("Missing auth.json path.")
            }
            tokens.removeFirst()
            try requireNoExtra(tokens)
            return .importAuth(path: path, alias: alias, json: json)
        case "switch":
            let restart = try restartPreference(from: &tokens)
            guard let selector = tokens.first else {
                throw CodexKeyringCLIParseError.usage("Missing account selector.")
            }
            tokens.removeFirst()
            try requireNoExtra(tokens)
            return .switchAccount(selector: selector, restart: restart, json: json)
        case "rename":
            guard tokens.count >= 2 else {
                throw CodexKeyringCLIParseError.usage("Usage: ckr rename <account> <new-alias>")
            }
            let selector = tokens.removeFirst()
            let alias = tokens.removeFirst()
            try requireNoExtra(tokens)
            return .rename(selector: selector, alias: alias, json: json)
        case "remove":
            let confirmed = removeFlag("--yes", from: &tokens) || removeFlag("-y", from: &tokens)
            guard let selector = tokens.first else {
                throw CodexKeyringCLIParseError.usage("Missing account selector.")
            }
            tokens.removeFirst()
            try requireNoExtra(tokens)
            return .remove(selector: selector, confirmed: confirmed, json: json)
        case "settings":
            return try parseSettings(tokens, json: json)
        case "quota":
            return try parseQuota(tokens, json: json)
        default:
            throw CodexKeyringCLIParseError.usage("Unknown command '\(command)'.")
        }
    }

    private func parseSettings(_ tokens: [String], json: Bool) throws -> CodexKeyringCLICommand {
        var tokens = tokens
        guard let subcommand = tokens.first else {
            throw CodexKeyringCLIParseError.usage("Usage: ckr settings <get|set>")
        }
        tokens.removeFirst()
        switch subcommand {
        case "get":
            try requireNoExtra(tokens)
            return .settingsGet(json: json)
        case "set":
            guard tokens.count == 2 else {
                throw CodexKeyringCLIParseError.usage("Usage: ckr settings set <key> <value>")
            }
            return .settingsSet(key: tokens[0], value: tokens[1], json: json)
        default:
            throw CodexKeyringCLIParseError.usage("Unknown settings command '\(subcommand)'.")
        }
    }

    private func parseQuota(_ tokens: [String], json: Bool) throws -> CodexKeyringCLICommand {
        var tokens = tokens
        guard let subcommand = tokens.first else {
            throw CodexKeyringCLIParseError.usage("Usage: ckr quota refresh")
        }
        tokens.removeFirst()
        guard subcommand == "refresh" else {
            throw CodexKeyringCLIParseError.usage("Unknown quota command '\(subcommand)'.")
        }
        try requireNoExtra(tokens)
        return .quotaRefresh(json: json)
    }

    private func restartPreference(
        from tokens: inout [String]
    ) throws -> CodexKeyringCLICommand.RestartPreference {
        let restart = removeFlag("--restart", from: &tokens)
        let noRestart = removeFlag("--no-restart", from: &tokens)
        guard !(restart && noRestart) else {
            throw CodexKeyringCLIParseError.usage("Use only one of --restart or --no-restart.")
        }
        if restart { return .restart }
        if noRestart { return .noRestart }
        return .settingsDefault
    }

    private func removeFlag(_ flag: String, from tokens: inout [String]) -> Bool {
        guard let index = tokens.firstIndex(of: flag) else { return false }
        tokens.remove(at: index)
        return true
    }

    private func removeValue(_ flag: String, from tokens: inout [String]) throws -> String? {
        guard let index = tokens.firstIndex(of: flag) else { return nil }
        tokens.remove(at: index)
        guard index < tokens.count else {
            throw CodexKeyringCLIParseError.usage("Missing value for \(flag).")
        }
        return tokens.remove(at: index)
    }

    private func requireNoExtra(_ tokens: [String]) throws {
        guard tokens.isEmpty else {
            throw CodexKeyringCLIParseError.usage("Unexpected argument '\(tokens[0])'.")
        }
    }
}
