import Foundation

/// Request body bytes and an optional `Content-Type`.
///
/// `.json(Data)` is already-encoded bytes plus `application/json`.
/// Use `json(_:encoder:)` to encode an `Encodable` value.
/// `.raw` uses the given content type, or none.
nonisolated
public enum HTTPBody: Sendable {
    /// Encoded JSON. Content type is `application/json`.
    case json(Data)
    /// Arbitrary bytes. `contentType` is used only when the request does not
    /// already have a `Content-Type` header.
    case raw(Data, contentType: String?)

    /// Encodes `value` and returns `.json`.
    public static func json(
        _ value: some Encodable,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> HTTPBody {
        .json(try encoder.encode(value))
    }

    public var data: Data {
        switch self {
        case .json(let data), .raw(let data, _):
            data
        }
    }

    public var contentType: String? {
        switch self {
        case .json:
            "application/json"
        case .raw(_, let contentType):
            contentType
        }
    }
}
