import Foundation

extension AccountStoreStatusMessages {
    static func logExport(destination: URL) -> String {
        "Logs exported to \(destination.path)."
    }
}
