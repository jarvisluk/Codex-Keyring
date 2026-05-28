import SwiftUI
import CodexKeyringDomain

struct AccountDetailView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var showingRemoveConfirmation = false
    @State private var rename = AccountDetailRenameState()

    var account: CodexAccount

    private var isActive: Bool {
        store.activeAccount?.id == account.id
    }

    private var canSubmitAliasRename: Bool {
        store.canRename(account, to: rename.cleanedDraft)
    }

    var body: some View {
        ScrollView {
            AccountDetailContent(
                account: account,
                isActive: isActive,
                actionPresentation: actionPresentation,
                actionAvailability: actionAvailability,
                showingRenamePopover: $rename.isPresented,
                renameDraft: $rename.draft,
                onSwitch: switchToAccount,
                onBeginRename: beginAliasRename,
                onSubmitRename: submitAliasRename,
                onCancelRename: cancelAliasRename,
                onRemove: { showingRemoveConfirmation = true }
            )
        }
        .navigationTitle(account.displayName)
        .hidesWindowToolbarTitle()
        .onAppear {
            rename.reset(alias: account.alias)
        }
        .onChange(of: account.id) {
            rename.reset(alias: account.alias)
        }
        .onChange(of: account.alias) {
            rename.sync(alias: account.alias)
        }
        .confirmationDialog("Remove saved account?", isPresented: $showingRemoveConfirmation) {
            Button("Remove Snapshot", role: .destructive) {
                store.remove(account)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved snapshot only. It does not delete the current Codex auth.json.")
        }
    }

    private func beginAliasRename() {
        rename.begin(alias: account.alias)
    }

    private func cancelAliasRename() {
        rename.cancel()
    }

    private func submitAliasRename() {
        guard canSubmitAliasRename else { return }
        let cleanedDraft = rename.cleanedDraft
        rename.finish()
        store.rename(account, to: cleanedDraft)
    }

    private func switchToAccount() {
        store.switchTo(account, restartCodexApp: store.settings.restartCodexAppAfterSwitch)
    }

    private var actionPresentation: AccountDetailActionPresentation {
        AccountDetailActionPresentation(
            isActive: isActive,
            restartCodexAppAfterSwitch: store.settings.restartCodexAppAfterSwitch
        )
    }

    private var actionAvailability: AccountDetailActionAvailability {
        AccountDetailActionAvailability(
            canSubmitAliasRename: canSubmitAliasRename,
            canSwitch: store.canSwitch(to: account),
            canBeginRename: store.canBeginRename(account),
            canRemove: store.canRemove(account)
        )
    }
}
