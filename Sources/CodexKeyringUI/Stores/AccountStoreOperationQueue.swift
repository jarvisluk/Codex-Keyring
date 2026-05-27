import Foundation

@MainActor
final class AccountStoreOperationQueue {
    private var tail: Task<Void, Never>?
    private var lastScheduledID = 0

    func enqueue(
        operation: @escaping @MainActor @Sendable () async throws -> Void,
        onFailure: (@MainActor @Sendable (Error) -> Void)? = nil
    ) {
        lastScheduledID += 1
        let operationID = lastScheduledID
        let previous = tail

        let task = Task { @MainActor [weak self, previous] in
            await previous?.value
            guard let self else { return }

            do {
                try await operation()
            } catch {
                onFailure?(error)
            }

            if self.lastScheduledID == operationID {
                self.tail = nil
            }
        }

        tail = task
    }
}
