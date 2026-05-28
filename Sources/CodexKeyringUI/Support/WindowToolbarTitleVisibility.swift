import SwiftUI

extension View {
    @ViewBuilder
    func hidesWindowToolbarTitle() -> some View {
        if #available(macOS 15.0, *) {
            toolbar(removing: .title)
        } else {
            self
        }
    }

    @ViewBuilder
    func hidesWindowToolbarSeparator() -> some View {
        if #available(macOS 15.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            self
        }
    }
}
