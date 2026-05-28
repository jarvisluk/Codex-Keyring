import AppKit
import Foundation
import UniformTypeIdentifiers
import CodexKeyringDomain

@MainActor
enum SettingsFileActions {
    static func chooseLogExportDestination() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Codex Keyring Logs"
        panel.message = "Choose where to save the combined log file."
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultExportFileName()
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func revealLogs(directory: URL, currentLogFile: URL) throws {
        try reveal(.logs(directory: directory, currentLogFile: currentLogFile))
    }

    static func revealLocation(path: String, kind: SettingsLocationKind) throws {
        try reveal(.location(path: path, kind: kind))
    }

    private static func reveal(_ destination: SettingsFinderDestination) throws {
        if let directory = destination.directoryToPrepare {
            try prepareDirectoryForFinder(directory)
        }

        switch destination.action {
        case let .openDirectory(directory):
            try openDirectoryInFinder(directory)
        case let .selectFile(file):
            NSWorkspace.shared.activateFileViewerSelecting([file])
        }
    }

    private static func prepareDirectoryForFinder(_ directory: URL) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not prepare \(directory.path): \(error.localizedDescription)"
            )
        }
    }

    private static func openDirectoryInFinder(_ directory: URL) throws {
        guard NSWorkspace.shared.open(directory) else {
            throw CodexKeyringError.fileSystemFailure(reason: "Could not open \(directory.path) in Finder")
        }
    }

    private static func defaultExportFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "codex-keyring-\(formatter.string(from: date)).log.txt"
    }
}
