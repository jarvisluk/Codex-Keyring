import Foundation
import CodexKeyringDomain

extension AccountStore {
    public var logsDirectoryURL: URL {
        if let url = logService?.logsDirectoryURL { return url }
        return URL(fileURLWithPath: storageLocations.logsDirectoryPath, isDirectory: true)
    }

    public var currentLogFileURL: URL {
        if let url = logService?.currentLogFileURL { return url }
        return URL(fileURLWithPath: storageLocations.currentLogFilePath)
    }

    public var isLoggingAvailable: Bool {
        logService != nil
    }

    /// Export the rolling log files (current + retained generations) into the
    /// chosen destination as a single combined text file.
    public func exportLogs(to destination: URL) {
        guard !isLogExportInProgress else { return }
        lastError = nil
        guard let logService else {
            setError(CodexKeyringError.fileSystemFailure(reason: "Logging is not initialised; nothing to export."))
            return
        }
        isLogExportInProgress = true
        statusMessage = "Exporting logs..."

        AccountLogExporter.export(logService: logService, to: destination) { [weak self] result in
            self?.isLogExportInProgress = false
            switch result {
            case .success(let destination):
                self?.statusMessage = AccountStoreStatusMessages.logExport(destination: destination)
            case .failure(let error):
                self?.setError(error)
            }
        }
    }
}
