import SwiftUI

enum KeyringSurface {
    case regular
    case thin

    var material: Material {
        switch self {
        case .regular:
            return .regularMaterial
        case .thin:
            return .thinMaterial
        }
    }
}

extension View {
    func keyringSurface(
        _ surface: KeyringSurface = .regular,
        padding: CGFloat = KeyringStyle.Spacing.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .background(
                surface.material,
                in: RoundedRectangle(
                    cornerRadius: KeyringStyle.Radius.card,
                    style: .continuous
                )
            )
    }

    func accountStoreFailureAlert(_ store: AccountStore) -> some View {
        alert("Action failed", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("OK") {
                store.clearError()
            }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

struct KeyringSectionHeader: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
                .font(.headline)
        } else {
            Text(title)
                .font(.headline)
        }
    }
}

extension String {
    var cappedMenuBarText: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > KeyringStyle.Text.menuBarLimit else { return trimmed }
        return String(trimmed.prefix(KeyringStyle.Text.menuBarLimit - 3)) + "..."
    }
}
