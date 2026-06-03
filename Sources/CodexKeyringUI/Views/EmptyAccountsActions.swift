import SwiftUI

struct EmptyAccountsActions: View {
    let presentation: EmptyAccountsPresentation
    let onSaveCurrentLogin: () -> Void
    let onAddLogin: () -> Void
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: KeyringStyle.Spacing.compact) {
            if presentation.showsSaveCurrentLogin {
                Button {
                    onSaveCurrentLogin()
                } label: {
                    Label("Save Current Login", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!presentation.canSaveCurrentLogin)
            }

            addLoginButton

            Button {
                onImport()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(!presentation.canImport)
        }
        .padding(.top, KeyringStyle.Spacing.micro)
    }

    @ViewBuilder
    private var addLoginButton: some View {
        let button = Button {
            onAddLogin()
        } label: {
            Label(presentation.addLoginTitle, systemImage: presentation.addLoginSystemImage)
        }
        .disabled(!presentation.canAddLogin)
        .help(presentation.addLoginCancelsInProgress
            ? "Cancel the current Codex browser login."
            : "Open Codex login and save the new account without switching the current auth.")

        if presentation.usesProminentAddLoginButton {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
