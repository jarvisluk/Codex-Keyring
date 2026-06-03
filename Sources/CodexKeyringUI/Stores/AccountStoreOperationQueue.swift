import Foundation

@MainActor
final class AccountStoreOperationQueue {
    private var tail: Task<Void, Never>?
    private var lastScheduledID = 0

    @discardableResult
    func enqueue(
        operation: @escaping @MainActor @Sendable () async throws -> Void,
        onFailure: (@MainActor @Sendable (Error) -> Void)? = nil
    ) -> Task<Void, Never> {
        lastScheduledID += 1
        let operationID = lastScheduledID
        let previous = tail

        let task = Task { @MainActor [weak self, previous] in
            await previous?.value
            guard let self else { return }
            guard !Task.isCancelled else {
                if self.lastScheduledID == operationID {
                    self.tail = nil
                }
                return
            }

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
        return task
    }
}
