import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.section) {
            KeyringSectionHeader(title)

            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.contentGroup) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
