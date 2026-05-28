import SwiftUI
import CodexKeyringDomain

struct AccountDetailContent: View {
    let account: CodexAccount
    let isActive: Bool
    let actionPresentation: AccountDetailActionPresentation
    let actionAvailability: AccountDetailActionAvailability
    @Binding var showingRenamePopover: Bool
    @Binding var renameDraft: String
    let onSwitch: () -> Void
    let onBeginRename: () -> Void
    let onSubmitRename: () -> Void
    let onCancelRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.detailSection) {
            AccountDetailHeader(account: account, isActive: isActive)
            AccountDetailActions(
                presentation: actionPresentation,
                availability: actionAvailability,
                showingRenamePopover: $showingRenamePopover,
                renameDraft: $renameDraft,
                onSwitch: onSwitch,
                onBeginRename: onBeginRename,
                onSubmitRename: onSubmitRename,
                onCancelRename: onCancelRename,
                onRemove: onRemove
            )
            AccountQuotaDetailView(account: account)
            AccountDetailMetadataGrid(account: account)
        }
        .padding(KeyringStyle.Spacing.detailPagePadding)
        .frame(maxWidth: KeyringStyle.Layout.detailContentMaxWidth, alignment: .leading)
    }
}
