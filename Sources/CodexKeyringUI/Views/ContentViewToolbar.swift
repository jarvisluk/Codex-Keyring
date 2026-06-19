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
        ToolbarItem(placement: .navigation) {
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
        }

        ToolbarItem(placement: .navigation) {
            Button {
                importAuthFile()
            } label: {
                ToolbarActionLabel("Import", systemImage: "square.and.arrow.down")
            }
            .disabled(!toolbarPresentation.canImport)
            .help("Import Codex auth.json")
        }

        ToolbarItem(placement: .navigation) {
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
            .keyboardShortcut("r", modifiers: [.command])
            .help("Refresh accounts")
        }

        ToolbarItem {
            Spacer()
        }
    }

    func performToolbarLoginAction() {
        if toolbarPresentation.addLoginCancelsInProgress {
            cancelNewLogin()
        } else {
            startNewLogin()
        }
    }
}
