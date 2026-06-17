struct SettingsCommandLinePresentation: Equatable {
    let command: String
    let installTitle: String
    let uninstallTitle: String
    let installDestinationPath: String
    let note: String

    init(installDestinationPath: String = CommandLineInstaller.defaultDestinationURL.path) {
        command = "ckr status"
        installTitle = "Install ckr"
        uninstallTitle = "Uninstall"
        self.installDestinationPath = installDestinationPath
        note = "Use the short Terminal command for quick account checks. Run ckr --help to see the full command list."
    }
}
