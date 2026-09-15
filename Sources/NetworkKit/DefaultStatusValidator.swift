import Foundation

/// Accepts status codes in `200...299`.
///
/// Anything else throws `NetworkError.httpError` with the response body.
/// This type does not interpret that body as an API error model.
nonisolated
public struct DefaultStatusValidator: HTTPStatusValidator {

    public init() {}

    public func validate(
        _ response: HTTPURLResponse,
        data: Data
    ) throws {
        guard (200...299).contains(response.statusCode) else {
            throw NetworkError.httpError(
                statusCode: response.statusCode,
                data: data,
                response: response
            )
        }
    }
}
