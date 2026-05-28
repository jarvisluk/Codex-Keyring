struct SettingsLogsPresentation: Equatable {
    let exportTitle: String
    let exportSystemImage: String
    let canExportLogs: Bool

    init(isExportInProgress: Bool, canExportLogs: Bool) {
        exportTitle = isExportInProgress ? "Exporting Logs..." : "Export Logs..."
        exportSystemImage = isExportInProgress ? "hourglass" : "square.and.arrow.up"
        self.canExportLogs = canExportLogs
    }
}
