import SwiftUI

struct AccountDetailActions: View {
    let presentation: AccountDetailActionPresentation
    let availability: AccountDetailActionAvailability
    @Binding var showingRenamePopover: Bool
    @Binding var renameDraft: String
    let onSwitch: () -> Void
    let onBeginRename: () -> Void
    let onSubmitRename: () -> Void
    let onCancelRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: KeyringStyle.Spacing.small) {
            Button {
                onSwitch()
            } label: {
                Label(presentation.switchTitle, systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .help(presentation.switchHelpText)
            .disabled(!availability.canSwitch)

            Button {
                onBeginRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
            .disabled(!availability.canBeginRename)
            .popover(isPresented: $showingRenamePopover, arrowEdge: .bottom) {
                AccountRenamePopover(
                    renameDraft: $renameDraft,
                    canSubmit: availability.canSubmitAliasRename,
                    onCancel: onCancelRename,
                    onSubmit: onSubmitRename
                )
            }

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(!availability.canRemove)
        }
    }
}
