extension ContentView {
    func importAuthFile() {
        AuthImportPanel.chooseAndImport(using: store)
    }

    func startNewLogin() {
        guard store.canLoginNewAccount else { return }
        store.loginNewCodexAccount()
    }

    func showAddCurrentLoginSheet() {
        guard store.canAddCurrentLogin else { return }
        showingAddCurrentSheet = true
    }
}
