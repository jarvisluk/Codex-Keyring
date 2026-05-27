import AppKit
import UniformTypeIdentifiers

public enum AuthImportPanel {
    @MainActor
    public static func chooseAndImport(using store: AccountStore) {
        let panel = NSOpenPanel()
        panel.title = "Import Codex auth.json"
        panel.message = "Choose a Codex auth JSON file. Token contents stay on this Mac."
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            let scope: URLAccessScope?
            if url.startAccessingSecurityScopedResource() {
                scope = URLAccessScope {
                    url.stopAccessingSecurityScopedResource()
                }
            } else {
                scope = nil
            }
            store.importAccount(from: url, accessScope: scope)
        }
    }
}
