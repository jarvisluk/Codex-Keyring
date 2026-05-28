import Darwin
import Foundation

extension OAuthCallbackServer {
    /// Binds to `defaultPort` first, falling back to `fallbackPort` and then to
    /// an arbitrary ephemeral port. The chosen port is exposed via `port`.
    static func start(
        expectedState: String,
        candidatePorts candidates: [UInt16] = [defaultPort, fallbackPort, 0]
    ) async throws -> OAuthCallbackServer {
        var lastError: String = "no port available"
        for candidate in candidates {
            do {
                let (fd, port) = try OAuthCallbackSocketBinder.bind(port: candidate)
                let server = OAuthCallbackServer(
                    expectedState: expectedState,
                    listener: OAuthListenerState(fd: fd),
                    port: port
                )
                await server.startAccepting()
                return server
            } catch let ServerError.bindFailed(reason) {
                lastError = reason
                continue
            } catch {
                lastError = error.localizedDescription
                continue
            }
        }
        throw ServerError.bindFailed(lastError)
    }

    func startAccepting() {
        let listener = listener
        let connectionQueue = connectionQueue
        acceptQueue.async { [weak self] in
            OAuthCallbackSocketLoop.run(listener: listener, connectionQueue: connectionQueue) { [weak self] queryItems, clientFD in
                Task {
                    guard let self else {
                        close(clientFD)
                        return
                    }
                    await self.handleCallback(queryItems: queryItems, clientFD: clientFD)
                }
            }
        }
    }
}
