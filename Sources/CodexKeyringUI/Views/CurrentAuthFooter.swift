import SwiftUI

struct CurrentAuthFooter: View {
    @EnvironmentObject private var store: AccountStore
    let onAddCurrentLogin: () -> Void

    private var presentation: CurrentAuthFooterPresentation {
        CurrentAuthFooterPresentation(
            metadata: store.currentAuthMetadata,
            savedAccount: store.savedAccountForCurrentAuth,
            authPath: store.storageLocations.codexAuthPath,
            showsSaveAction: store.canSaveCurrentAuth,
            canSaveAction: store.canAddCurrentLogin
        )
    }

    var body: some View {
        HStack(spacing: KeyringStyle.Spacing.compact) {
            Image(systemName: presentation.statusSystemImage)
                .foregroundStyle(presentation.statusIconTint.color)
                .frame(width: KeyringStyle.Icon.rowWidth)

            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.micro) {
                Text("Current Codex Auth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(presentation.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if presentation.showsSaveAction {
                Button {
                    onAddCurrentLogin()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .help("Save the current Codex auth as a named account.")
                .accessibilityLabel("Save Current Login")
                .disabled(!presentation.canSaveAction)
            }
        }
        .keyringSurface(.thin, padding: KeyringStyle.Spacing.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilitySummary)
        .contextMenu {
            Button {
                onAddCurrentLogin()
            } label: {
                Label(presentation.contextMenuTitle, systemImage: "plus.circle")
            }
            .disabled(!presentation.canSaveAction)
        }
        .help(store.storageLocations.codexAuthPath)
    }
}
