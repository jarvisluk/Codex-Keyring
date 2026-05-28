import SwiftUI

struct SettingsLocationsSection: View {
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        SettingsSection("Locations") {
            Grid(
                alignment: .leading,
                horizontalSpacing: KeyringStyle.Grid.locationHorizontalSpacing,
                verticalSpacing: KeyringStyle.Grid.locationVerticalSpacing
            ) {
                SettingsLocationRow("Codex auth", path: store.storageLocations.codexAuthPath, revealKind: .file) {
                    revealLocation(path: $0, kind: $1)
                }
                SettingsLocationRow("App data", path: store.storageLocations.applicationSupportPath, revealKind: .directory) {
                    revealLocation(path: $0, kind: $1)
                }
                SettingsLocationRow("Accounts", path: store.storageLocations.accountsDirectoryPath, revealKind: .directory) {
                    revealLocation(path: $0, kind: $1)
                }
                SettingsLocationRow("Backups", path: store.storageLocations.backupsDirectoryPath, revealKind: .directory) {
                    revealLocation(path: $0, kind: $1)
                }
            }
        }
    }

    private func revealLocation(path: String, kind: SettingsLocationKind) {
        do {
            try SettingsFileActions.revealLocation(path: path, kind: kind)
        } catch {
            store.reportUserFacingError(error)
        }
    }
}
