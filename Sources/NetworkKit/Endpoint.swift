import Foundation

/// One HTTP operation, relative to a service `baseURL`.
///
/// `Response` is a phantom type. Use a `Decodable` model for JSON, or `Void`
/// when there is no body to decode (for example `204`).
///
/// The stored `path` has every leading `/` stripped. Pass a raw path such as
/// `"users/42"`, not a percent-encoded string — `URL.append(path:)` encodes
/// it when the request is built. This type does not accept absolute URLs.
nonisolated
public struct Endpoint<Response>: Sendable {

    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]
    public let headers: HTTPHeaders
    public let body: HTTPBody?

    /// Seconds before the request times out.
    ///
    /// Applied to the `URLRequest` when set. `nil` leaves `URLRequest`'s
    /// default of 60 seconds. Session limits such as
    /// `timeoutIntervalForResource` stay on the `URLSession`.
    public let timeoutInterval: TimeInterval?

    /// Creates an endpoint.
    ///
    /// Leading slashes on `path` are stripped (`"/users"` and `"users"` are
    /// the same). Query items are appended to the service base URL as-is,
    /// including duplicate names. `timeoutInterval`, in seconds, is copied
    /// onto the request when set.
    public init(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        headers: HTTPHeaders = HTTPHeaders(),
        body: HTTPBody? = nil,
        timeoutInterval: TimeInterval? = nil
    ) {
        self.path = String(path.drop(while: { $0 == "/" }))
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
    }
}
