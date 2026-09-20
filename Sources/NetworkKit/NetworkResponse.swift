import Foundation

/// A decoded value plus the HTTP response it came from.
///
/// `Value` is `Void` when the endpoint has no body to decode — the HTTP
/// response is still here. `request` still returns only `value`, or nothing
/// for `Void`.
nonisolated
public struct NetworkResponse<Value: Sendable>: Sendable {
    public let value: Value
    public let data: Data
    public let response: HTTPURLResponse

    public var statusCode: Int {
        response.statusCode
    }

    public var headers: HTTPHeaders {
        HTTPHeaders(response)
    }

    public init(
        value: Value,
        data: Data,
        response: HTTPURLResponse
    ) {
        self.value = value
        self.data = data
        self.response = response
    }
}
