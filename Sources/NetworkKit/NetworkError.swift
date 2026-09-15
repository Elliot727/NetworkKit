import Foundation

/// Errors produced by NetworkKit itself.
///
/// `request` also throws `URLError` from `URLSession`, `CancellationError`
/// when the task is cancelled, and `DecodingError` (or a custom decoder's
/// error) when the body cannot be decoded. Those are not wrapped.
nonisolated
public enum NetworkError: Error, Sendable {
    /// The transport returned a non-HTTP response.
    case invalidResponse
    /// The status was outside the validator's accepted range.
    ///
    /// `data` is the raw response body so callers can decode an API error
    /// model. This type does not interpret that body.
    case httpError(
        statusCode: Int,
        data: Data,
        response: HTTPURLResponse
    )
}
