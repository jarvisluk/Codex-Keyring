import Foundation

public struct AccountStorageLocations: Sendable {
    public let codexAuthPath: String
    public let applicationSupportPath: String
    public let accountsDirectoryPath: String
    public let backupsDirectoryPath: String
    public let logsDirectoryPath: String
    public let currentLogFilePath: String

    public init(
        codexAuthPath: String,
        applicationSupportPath: String,
        accountsDirectoryPath: String,
        backupsDirectoryPath: String,
        logsDirectoryPath: String,
        currentLogFilePath: String
    ) {
        self.codexAuthPath = codexAuthPath
        self.applicationSupportPath = applicationSupportPath
        self.accountsDirectoryPath = accountsDirectoryPath
        self.backupsDirectoryPath = backupsDirectoryPath
        self.logsDirectoryPath = logsDirectoryPath
        self.currentLogFilePath = currentLogFilePath
    }
}
