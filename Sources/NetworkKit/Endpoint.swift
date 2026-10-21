import Foundation

/// One HTTP operation, relative to a service `baseURL`.
///
/// `Response` is a phantom type. Use a `Decodable` model for JSON, or `Void`
/// when there is no body to decode (for example `204`).
///
/// The stored `path` has every leading `/` stripped. Pass a raw path such as
/// `"users/42"`, not a percent-encoded string. `/` is a separator unless
/// `encodesPathSeparators` is set. This type does not accept absolute URLs.
nonisolated
public struct Endpoint<Response>: Sendable {

    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]
    public let headers: HTTPHeaders
    public let body: HTTPBody?

    /// When `true`, `/` in `path` is encoded as `%2F` and the path is one
    /// component. When `false`, `/` separates components.
    public let encodesPathSeparators: Bool

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
    /// onto the request when set. `encodesPathSeparators` encodes each `/`
    /// in `path` as `%2F` instead of treating it as a separator.
    public init(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        headers: HTTPHeaders = HTTPHeaders(),
        body: HTTPBody? = nil,
        timeoutInterval: TimeInterval? = nil,
        encodesPathSeparators: Bool = false
    ) {
        self.path = String(path.drop(while: { $0 == "/" }))
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.encodesPathSeparators = encodesPathSeparators
    }
}
