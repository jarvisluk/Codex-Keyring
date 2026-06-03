extension ContentView {
    func importAuthFile() {
        AuthImportPanel.chooseAndImport(using: store)
    }

    func startNewLogin() {
        guard store.canLoginNewAccount else { return }
        store.loginNewCodexAccount()
    }

    func cancelNewLogin() {
        store.cancelLoginNewCodexAccount()
    }

    func showAddCurrentLoginSheet() {
        guard store.canAddCurrentLogin else { return }
        showingAddCurrentSheet = true
    }
}
