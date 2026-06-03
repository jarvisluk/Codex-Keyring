import SwiftUI

extension ContentView {
    var toolbarPresentation: ContentToolbarPresentation {
        ContentToolbarPresentation(
            isSettingsPresented: settingsPresentation.isPresented,
            isLoginInProgress: store.isLoginInProgress,
            isRefreshInProgress: store.isRefreshInProgress,
            canLoginNewAccount: store.canLoginNewAccount,
            canImportAccount: store.canImportAccount,
            canRefreshAccounts: store.canRefreshAccounts
        )
    }

    @ToolbarContentBuilder
    var accountToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                performToolbarLoginAction()
            } label: {
                ToolbarActionLabel(
                    toolbarPresentation.addLoginTitle,
                    systemImage: toolbarPresentation.addLoginSystemImage
                )
            }
            .disabled(!toolbarPresentation.canAddLogin)
            .help(toolbarPresentation.addLoginCancelsInProgress
                ? "Cancel the current Codex browser login."
                : "Open Codex login and save the new account without switching the current auth.")

            Button {
                importAuthFile()
            } label: {
                ToolbarActionLabel("Import", systemImage: "square.and.arrow.down")
            }
            .disabled(!toolbarPresentation.canImport)
            .help("Import Codex auth.json")

            Button {
                store.refresh()
            } label: {
                ToolbarActionLabel(
                    "Refresh",
                    systemImage: "arrow.clockwise",
                    isLoading: toolbarPresentation.isRefreshLoading
                )
            }
            .disabled(!toolbarPresentation.canRefresh)
            .help("Refresh accounts")
        }
    }

    private func performToolbarLoginAction() {
        if toolbarPresentation.addLoginCancelsInProgress {
            cancelNewLogin()
        } else {
            startNewLogin()
        }
    }
}
