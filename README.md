
# NetworkKit

Small, typed Swift networking package. Define an `Endpoint`, execute it, validate the HTTP response, and decode the result.

There is no retry, middleware, auth refresh, caching, or logging.

## Usage

```swift
import NetworkKit

let service = DefaultNetworkService(
    baseURL: URL(string: "https://api.example.com/v1")!,
    defaultHeaders: HTTPHeaders([
        "Authorization": "Bearer …",
        "Accept": "application/json",
    ])
)

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

let users: [User] = try await service.request(
    Endpoint(path: "users", method: .get)
)

// Empty 2xx, such as 204. A model type throws DecodingError on an empty body.
try await service.request(
    Endpoint<Void>(path: "users/1", method: .delete)
)

let response: NetworkResponse<User> =
    try await service.requestWithResponse(
        Endpoint(path: "users/1", method: .get)
    )
let etag = response.headers.value(for: "ETag")

let deleted: NetworkResponse<Void> =
    try await service.requestWithResponse(
        Endpoint<Void>(path: "users/1", method: .delete)
    )
let location = deleted.headers.value(for: "Location")
```

Replace the whole `DefaultNetworkService` value when default headers change, for example when a token changes.

Pin the response type on `Endpoint` and the call site stays a named factory instead of a loose path:

```swift
struct NewUser: Encodable, Sendable {
    let name: String
}

extension Endpoint where Response == [User] {
    static var list: Self {
        Endpoint(path: "users", method: .get)
    }
}

extension Endpoint where Response == User {
    static func create(_ user: NewUser) throws -> Self {
        try Endpoint(
            path: "users",
            method: .post,
            body: .json(user)
        )
    }
}

let users: [User] = try await service.request(.list)
let created: User = try await service.request(.create(NewUser(name: "Ada")))
```

## Behaviour

**Paths** are relative to `baseURL`. Leading slashes are stripped. Pass a raw path (`users/42`), not a percent-encoded one. `/` separates components. Set `encodesPathSeparators: true` when a slash is part of one component and must be sent as `%2F`. Absolute URLs are not supported.

**Headers** are merged in this order:

1. Service defaults
2. Endpoint headers
3. Body `Content-Type`, only when no explicit `Content-Type` exists

Endpoint headers therefore override service defaults.

**JSON bodies** can be created with `try .json(value)`, which encodes an `Encodable` value. `.json(Data)` is for JSON bytes you already have.

**Timeouts.** Set `timeoutInterval` on an `Endpoint` (seconds) to copy it onto the `URLRequest`. `nil` leaves `URLRequest`'s default of 60 seconds. Put other session settings, such as `timeoutIntervalForResource`, on a custom `URLSession` passed to `URLSessionTransport`.

**Empty bodies.** `Endpoint<Void>` accepts an empty `2xx` body, such as `204`, and skips decoding. A model response type always decodes, so that same empty body throws `DecodingError`.

**Errors** from `request` and `requestWithResponse`:

| Thrown                                              | When                                                                       |
| --------------------------------------------------- | -------------------------------------------------------------------------- |
| `NetworkError.httpError(statusCode:data:response:)` | HTTP status is outside `200...299`. `data` contains the raw response body. |
| `NetworkError.invalidResponse`                      | The transport did not return an `HTTPURLResponse`.                         |
| `URLError`                                          | The underlying transport or connectivity operation failed.                 |
| `CancellationError`                                 | The task was cancelled.                                                    |
| `DecodingError` / decoder-specific error            | Response decoding failed, including an empty body for a model type.        |

NetworkKit does not map HTTP error bodies onto an application-specific `APIError` type. Decode the raw `data` yourself when needed.

A successful `request` returns only the decoded value, or nothing for `Endpoint<Void>`. Use `requestWithResponse` when you need status, headers, or the raw body (`ETag`, `Link`, `Location`, rate-limit headers). That includes `Endpoint<Void>` — the body is not decoded, but the HTTP response is still returned.

## Customization

`DefaultNetworkService` accepts custom `HTTPTransport`, `HTTPStatusValidator`, and `ResponseDecoder` implementations.

For example, use a custom `URLSession` and configured `JSONDecoder`:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let service = DefaultNetworkService(
    baseURL: url,
    transport: URLSessionTransport(session: customSession),
    decoder: JSONResponseDecoder(decoder: decoder)
)
```

## License

MIT. See [LICENSE](LICENSE).
