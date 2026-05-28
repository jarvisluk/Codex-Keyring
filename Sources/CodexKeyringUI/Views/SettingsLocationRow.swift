import SwiftUI

struct SettingsLocationRow: View {
    let title: String
    let path: String
    let revealKind: SettingsLocationKind?
    let onReveal: (String, SettingsLocationKind) -> Void

    init(
        _ title: String,
        path: String,
        revealKind: SettingsLocationKind? = nil,
        onReveal: @escaping (String, SettingsLocationKind) -> Void = { _, _ in }
    ) {
        self.title = title
        self.path = path
        self.revealKind = revealKind
        self.onReveal = onReveal
    }

    var body: some View {
        GridRow {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: KeyringStyle.Layout.settingsLocationLabelWidth, alignment: .trailing)

            Text(path)
                .font(.callout.monospaced())
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(path)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let revealKind {
                Button {
                    onReveal(path, revealKind)
                } label: {
                    Label("Reveal", systemImage: revealKind.systemImage)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Reveal \(title) in Finder.")
            }
        }
    }
}
