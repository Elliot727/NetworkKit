import Foundation

/// Builds `URLRequest`s from `Endpoint`s and runs transport → validate → decode.
///
/// Header merge: `defaultHeaders`, then endpoint headers (endpoint wins on
/// the same name). Body `Content-Type` is applied only if that header is
/// still missing.
///
/// Recreate the value when default headers change (for example a new token).
/// There is no retry or auth refresh. Use `requestWithResponse` for status
/// and success-response headers.
nonisolated
public struct DefaultNetworkService: NetworkService {
    private let baseURL: URL
    private let defaultHeaders: HTTPHeaders
    private let transport: HTTPTransport
    private let validator: HTTPStatusValidator
    private let decoder: ResponseDecoder

    /// Creates a service.
    ///
    /// `baseURL` should include any API prefix (`https://api.example.com/v1`).
    /// Paths from endpoints are appended with `URL.append(path:)`.
    /// The default transport uses `URLSession.shared`.
    public init(
        baseURL: URL,
        defaultHeaders: HTTPHeaders = HTTPHeaders(),
        transport: HTTPTransport = URLSessionTransport(
            session: .shared
        ),
        validator: HTTPStatusValidator = DefaultStatusValidator(),
        decoder: ResponseDecoder = JSONResponseDecoder()
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.transport = transport
        self.validator = validator
        self.decoder = decoder
    }

    /// Decodes a JSON (or custom decoder) body after a successful status.
    ///
    /// Empty `2xx` bodies fail decoding — use `Endpoint<Void>` instead.
    public func request<Response: Decodable>(
        _ endpoint: Endpoint<Response>
    ) async throws -> Response {
        let (data, _) = try await executeValidated(endpoint)
        return try decoder.decode(data)
    }

    /// Validates status and returns. The body is not decoded.
    public func request(
        _ endpoint: Endpoint<Void>
    ) async throws {
        _ = try await executeValidated(endpoint)
    }

    /// Same pipeline as `request`, including the HTTP response.
    public func requestWithResponse<Response: Decodable & Sendable>(
        _ endpoint: Endpoint<Response>
    ) async throws -> NetworkResponse<Response> {
        let (data, response) = try await executeValidated(endpoint)
        return NetworkResponse(
            value: try decoder.decode(data),
            data: data,
            response: response
        )
    }

    /// Same pipeline as `request` for empty bodies, including the HTTP response.
    public func requestWithResponse(
        _ endpoint: Endpoint<Void>
    ) async throws -> NetworkResponse<Void> {
        let (data, response) = try await executeValidated(endpoint)
        return NetworkResponse(
            value: (),
            data: data,
            response: response
        )
    }

    private func executeValidated<Response>(
        _ endpoint: Endpoint<Response>
    ) async throws -> (Data, HTTPURLResponse) {
        let request = makeURLRequest(endpoint)
        let (data, response) = try await transport.execute(request)
        try validator.validate(response, data: data)
        return (data, response)
    }

    private func makeURLRequest<Response>(
        _ endpoint: Endpoint<Response>
    ) -> URLRequest {
        var url = baseURL

        if !endpoint.path.isEmpty {
            url.append(path: endpoint.path)
        }

        if !endpoint.queryItems.isEmpty {
            url.append(queryItems: endpoint.queryItems)
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        var headers = defaultHeaders.dictionary
        headers.merge(endpoint.headers.dictionary) { _, endpointValue in
            endpointValue
        }

        request.allHTTPHeaderFields = headers

        if let body = endpoint.body {
            request.httpBody = body.data

            if let contentType = body.contentType,
               request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue(
                    contentType,
                    forHTTPHeaderField: "Content-Type"
                )
            }
        }

        return request
    }
}
