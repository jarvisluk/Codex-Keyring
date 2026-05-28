import Foundation

struct AccountDetailActionPresentation: Equatable {
    let switchTitle: String
    let switchHelpText: String

    init(isActive: Bool, restartCodexAppAfterSwitch: Bool) {
        self.switchTitle = isActive ? "Switch Again" : "Switch"
        if restartCodexAppAfterSwitch {
            self.switchHelpText = "Switch auth and restart Codex App so it reloads the account immediately."
        } else {
            self.switchHelpText = "Switch Codex CLI auth only. Restart Codex App yourself if it is already open."
        }
    }
}

struct AccountDetailActionAvailability: Equatable {
    let canSubmitAliasRename: Bool
    let canSwitch: Bool
    let canBeginRename: Bool
    let canRemove: Bool
}
