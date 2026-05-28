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
            Label("Add Login", systemImage: presentation.addLoginSystemImage)
        }
        .disabled(!presentation.canAddLogin)

        if presentation.usesProminentAddLoginButton {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
