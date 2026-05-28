import Foundation

extension OAuthCallbackServer {
    /// Awaits the next valid `/auth/callback` request, with a timeout (defaults
    /// to 120 seconds to match the upstream Codex behaviour).
    func waitForCode(timeout: Duration = .seconds(120)) async throws -> OAuthCallbackResult {
        do {
            return try await withTaskCancellationHandler {
                try await waitForCodeUntilFinished(timeout: timeout)
            } onCancel: {
                Task { await self.finish(with: .failure(ServerError.cancelled)) }
            }
        } catch is CancellationError {
            finish(with: .failure(ServerError.cancelled))
            throw ServerError.cancelled
        }
    }

    func shutdown() {
        finish(with: .failure(ServerError.cancelled))
    }

    func finish(with result: Result<OAuthCallbackResult, Error>) {
        guard !didFinish else { return }
        didFinish = true
        finishedResult = result
        let pending = continuation
        continuation = nil

        listener.stop()

        switch result {
        case .success(let value):
            pending?.resume(returning: value)
        case .failure(let error):
            pending?.resume(throwing: error)
        }
    }

    private func waitForCodeUntilFinished(timeout: Duration) async throws -> OAuthCallbackResult {
        try await withThrowingTaskGroup(of: OAuthCallbackResult.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OAuthCallbackResult, Error>) in
                    Task { await self.installContinuation(continuation) }
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                let timeoutError = ServerError.timedOut
                await self.finish(with: .failure(timeoutError))
                throw timeoutError
            }

            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw ServerError.cancelled
            }
            return first
        }
    }

    private func installContinuation(_ continuation: CheckedContinuation<OAuthCallbackResult, Error>) {
        if let finishedResult {
            switch finishedResult {
            case .success(let value):
                continuation.resume(returning: value)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
            return
        }
        guard !didFinish else {
            continuation.resume(throwing: ServerError.cancelled)
            return
        }
        self.continuation = continuation
    }
}
