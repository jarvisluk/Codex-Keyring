import SwiftUI

enum KeyringStyle {
    enum Icon {
        static let rowWidth: CGFloat = 18
        static let statusSize: CGFloat = 14
        static let toolbarSize: CGFloat = 16
        static let emptyStateSize: CGFloat = 44
    }

    enum Radius {
        static let card: CGFloat = 8
    }

    enum Spacing {
        static let micro: CGFloat = 2
        static let inlineTight: CGFloat = 4
        static let note: CGFloat = 6
        static let small: CGFloat = 8
        static let compact: CGFloat = 10
        static let section: CGFloat = 12
        static let contentGroup: CGFloat = 14
        static let cardPadding: CGFloat = 16
        static let detailSection: CGFloat = 20
        static let settingsSection: CGFloat = 22
        static let sidebarFooterPadding: CGFloat = 10
        static let detailPagePadding: CGFloat = 24
        static let settingsHorizontalPadding: CGFloat = 32
        static let settingsVerticalPadding: CGFloat = 28
        static let settingsControlTextIndent: CGFloat = 26
        static let settingsActionIndentOffset: CGFloat = 16
    }

    enum Grid {
        static let compactHorizontalSpacing: CGFloat = 12
        static let compactVerticalSpacing: CGFloat = 6
        static let metadataHorizontalSpacing: CGFloat = 18
        static let locationHorizontalSpacing: CGFloat = 16
        static let locationVerticalSpacing: CGFloat = 10
    }

    enum Layout {
        static let detailContentMaxWidth: CGFloat = 760
        static let settingsLocationLabelWidth: CGFloat = 104
        static let settingsQuotaLabelWidth: CGFloat = 148
        static let settingsQuotaPickerWidth: CGFloat = 150
        static let settingsWindowWidth: CGFloat = 700
        static let settingsWindowHeight: CGFloat = 560
        static let aliasFieldMaxWidth: CGFloat = 280
        static let sheetWidth: CGFloat = 420
        static let sheetTextFieldWidth: CGFloat = 320
    }

    enum Text {
        static let menuBarLimit = 30
    }
}
