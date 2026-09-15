import Foundation

/// `HTTPTransport` backed by `URLSession.data(for:)`.
///
/// Cancellation of the calling task cancels the transfer and throws
/// `CancellationError`. Non-HTTP responses throw `NetworkError.invalidResponse`.
nonisolated
public struct URLSessionTransport: HTTPTransport {
    public let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    public func execute(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        return (data, httpResponse)
    }
}
