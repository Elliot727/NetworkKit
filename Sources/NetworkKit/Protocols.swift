import Foundation

/// Executes typed HTTP endpoints.
public protocol NetworkService: Sendable {
    /// Builds a request, executes it, validates the status, then decodes `data`.
    func request<Response: Decodable>(
        _ endpoint: Endpoint<Response>
    ) async throws -> Response

    /// Same pipeline with no decoding. Use for empty bodies such as `204`.
    func request(
        _ endpoint: Endpoint<Void>
    ) async throws
}

/// Sends a `URLRequest` and returns HTTP bytes.
///
/// Must throw `NetworkError.invalidResponse` when the response is not an
/// `HTTPURLResponse`.
public protocol HTTPTransport: Sendable {
    func execute(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse)
}

/// HTTP status policy only. Must not decode an application error model.
///
/// `data` is provided so implementations can attach it to the thrown error.
public protocol HTTPStatusValidator: Sendable {
    func validate(
        _ response: HTTPURLResponse,
        data: Data
    ) throws
}

/// Turns response bytes into a `Decodable` value.
public protocol ResponseDecoder: Sendable {
    func decode<T: Decodable>(
        _ data: Data
    ) throws -> T
}
