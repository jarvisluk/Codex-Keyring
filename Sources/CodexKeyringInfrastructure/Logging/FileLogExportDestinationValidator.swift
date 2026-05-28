import Foundation

struct FileLogExportDestinationValidator {
    let destination: URL
    let protectedLogFileURLs: [URL]
    let fileManager: FileManager

    func validate() throws {
        let destinationPath = destination.standardizedFileURL.path
        let protectedPaths = Set(protectedLogFileURLs.map { $0.standardizedFileURL.path })
        guard !protectedPaths.contains(destinationPath) else {
            throw FileLogSinkError.exportFailed(
                reason: "Choose a destination outside Codex Keyring's active log files."
            )
        }

        var isDirectory = ObjCBool(false)
        if fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                throw FileLogSinkError.exportFailed(reason: "Choose a file destination, not a directory.")
            }
        }
    }
}
