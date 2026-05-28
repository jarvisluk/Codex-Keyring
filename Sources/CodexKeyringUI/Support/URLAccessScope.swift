import Foundation

public struct URLAccessScope: Sendable {
    private let stopAccessing: @MainActor @Sendable () -> Void

    public init(stopAccessing: @escaping @MainActor @Sendable () -> Void) {
        self.stopAccessing = stopAccessing
    }

    @MainActor
    func stop() {
        stopAccessing()
    }
}
