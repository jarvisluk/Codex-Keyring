import Foundation

enum SettingsLocationKind {
    case directory
    case file

    var systemImage: String {
        switch self {
        case .directory:
            return "folder"
        case .file:
            return "doc.text.magnifyingglass"
        }
    }
}

struct SettingsFinderDestination: Equatable {
    enum Action: Equatable {
        case openDirectory(URL)
        case selectFile(URL)
    }

    let directoryToPrepare: URL?
    let action: Action

    static func logs(
        directory: URL,
        currentLogFile: URL,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> SettingsFinderDestination {
        if fileExists(currentLogFile.path) {
            return SettingsFinderDestination(
                directoryToPrepare: directory,
                action: .selectFile(currentLogFile)
            )
        }

        return SettingsFinderDestination(
            directoryToPrepare: directory,
            action: .openDirectory(directory)
        )
    }

    static func location(
        path: String,
        kind: SettingsLocationKind,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> SettingsFinderDestination {
        let url = URL(fileURLWithPath: path, isDirectory: kind == .directory)

        switch kind {
        case .directory:
            return SettingsFinderDestination(
                directoryToPrepare: url,
                action: .openDirectory(url)
            )
        case .file:
            if fileExists(url.path) {
                return SettingsFinderDestination(
                    directoryToPrepare: nil,
                    action: .selectFile(url)
                )
            }

            let parent = url.deletingLastPathComponent()
            return SettingsFinderDestination(
                directoryToPrepare: parent,
                action: .openDirectory(parent)
            )
        }
    }
}
