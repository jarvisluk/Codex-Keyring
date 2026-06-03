import AppKit
import SwiftUI

public struct AppMenuBarIconView: View {
    private let isActive: Bool

    public init(isActive: Bool) {
        self.isActive = isActive
    }

    public var body: some View {
        icon
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.primary)
            .opacity(isActive ? 1 : 0.66)
            .frame(width: KeyringStyle.Icon.menuBarSize, height: KeyringStyle.Icon.menuBarSize)
            .accessibilityHidden(true)
    }

    private var icon: Image {
        if let image = Self.menuBarIconImage {
            return Image(nsImage: image)
        }

        return Image(systemName: "key.horizontal")
    }

    private static let menuBarIconImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(
            width: KeyringStyle.Icon.menuBarSize,
            height: KeyringStyle.Icon.menuBarSize
        )
        return image
    }()
}
