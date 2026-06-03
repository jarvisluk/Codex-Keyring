import SwiftUI

@MainActor
public final class SettingsPresentationStore: ObservableObject {
    @Published public private(set) var isPresented = false

    public init() {}

    public func present() {
        isPresented = true
    }

    public func dismiss() {
        isPresented = false
    }
}
