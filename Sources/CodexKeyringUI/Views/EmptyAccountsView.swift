import SwiftUI

struct EmptyAccountsView: View {
    @EnvironmentObject private var store: AccountStore

    let onAddCurrentLogin: () -> Void
    let onImport: () -> Void

    private var presentation: EmptyAccountsPresentation {
        EmptyAccountsPresentation(
            canSaveCurrentAuth: store.canSaveCurrentAuth,
            canAddCurrentLogin: store.canAddCurrentLogin,
            isLoginInProgress: store.isLoginInProgress,
            canLoginNewAccount: store.canLoginNewAccount,
            canImportAccount: store.canImportAccount
        )
    }

    var body: some View {
        VStack(spacing: KeyringStyle.Spacing.cardPadding) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: KeyringStyle.Icon.emptyStateSize))
                .foregroundStyle(.secondary)

            Text("No saved accounts")
                .font(.title2.weight(.semibold))

            Text("Add a Codex login or import an auth.json snapshot to begin.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            EmptyAccountsActions(
                presentation: presentation,
                onSaveCurrentLogin: onAddCurrentLogin,
                onAddLogin: startNewLogin,
                onImport: onImport
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(KeyringStyle.Spacing.detailPagePadding)
    }

    private func startNewLogin() {
        guard presentation.canAddLogin else { return }
        store.loginNewCodexAccount()
    }
}
