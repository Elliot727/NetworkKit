import Foundation
import Testing
import NetworkKit

private struct User: Decodable, Equatable, Sendable {
    let id: Int
}

private actor RequestCapture {
    private(set) var request: URLRequest?

    func store(_ request: URLRequest) {
        self.request = request
    }
}

private struct StubTransport: HTTPTransport {
    let data: Data
    let statusCode: Int
    let headerFields: [String: String]?
    let capture: RequestCapture

    init(
        data: Data = Data(),
        statusCode: Int = 200,
        headerFields: [String: String]? = nil,
        capture: RequestCapture = RequestCapture()
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headerFields = headerFields
        self.capture = capture
    }

    func execute(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        await capture.store(request)
        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        )!
        return (data, response)
    }
}

private struct FailingTransport: HTTPTransport {
    let error: any Error & Sendable

    func execute(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        throw error
    }
}

/// `HTTPURLResponse` whose `allHeaderFields` can hold non-string values.
private final class HeaderFieldResponse: HTTPURLResponse, @unchecked Sendable {
    private let fields: [AnyHashable: Any]

    init(fields: [AnyHashable: Any]) {
        self.fields = fields
        super.init(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var allHeaderFields: [AnyHashable: Any] { fields }
}

private func makeService(
    baseURL: URL = URL(string: "https://api.example.com/v1")!,
    defaultHeaders: HTTPHeaders = HTTPHeaders(),
    transport: any HTTPTransport,
    validator: any HTTPStatusValidator = DefaultStatusValidator(),
    decoder: any ResponseDecoder = JSONResponseDecoder()
) -> DefaultNetworkService {
    DefaultNetworkService(
        baseURL: baseURL,
        defaultHeaders: defaultHeaders,
        transport: transport,
        validator: validator,
        decoder: decoder
    )
}

// MARK: - Endpoint

@Test func pathStripsLeadingSlashes() {
    #expect(Endpoint<Void>(path: "users", method: .get).path == "users")
    #expect(Endpoint<Void>(path: "/users", method: .get).path == "users")
    #expect(Endpoint<Void>(path: "///users", method: .get).path == "users")
    #expect(Endpoint<Void>(path: "", method: .get).path == "")
}

// MARK: - HTTPHeaders

@Test func headersAreCaseInsensitive() {
    var headers = HTTPHeaders(["Authorization": "Bearer a"])
    #expect(headers.value(for: "authorization") == "Bearer a")
    #expect(headers.value(for: "AUTHORIZATION") == "Bearer a")
    #expect(headers.dictionary["authorization"] == "Bearer a")
    #expect(headers.dictionary["Authorization"] == nil)

    headers.set("Bearer b", for: "AUTHORIZATION")
    #expect(headers.value(for: "Authorization") == "Bearer b")
    #expect(headers.dictionary.count == 1)
}

@Test func headersFromResponseLowercaseNames() {
    let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: [
            "ETag": "\"abc\"",
            "X-RateLimit-Remaining": "9",
        ]
    )!
    let headers = HTTPHeaders(response)

    #expect(headers.dictionary["etag"] == "\"abc\"")
    #expect(headers.dictionary["Etag"] == nil)
    #expect(headers.dictionary["ETag"] == nil)
    #expect(headers.value(for: "ETag") == "\"abc\"")
    #expect(headers.dictionary["x-ratelimit-remaining"] == "9")
    #expect(headers.value(for: "X-RateLimit-Remaining") == "9")
}

@Test func headersFromResponseCoerceNonStringValues() {
    final class Box: CustomStringConvertible {
        var description: String { "token-1" }
    }

    let response = HeaderFieldResponse(fields: [
        "ETag": "\"abc\"",
        "X-Count": NSNumber(value: 12),
        "X-Token": Box(),
        1: "ignored",
    ])
    let headers = HTTPHeaders(response)

    #expect(headers.dictionary["etag"] == "\"abc\"")
    #expect(headers.value(for: "x-count") == "12")
    #expect(headers.value(for: "x-token") == "token-1")
    #expect(headers.dictionary["1"] == nil)
    #expect(headers.dictionary.count == 3)
}

// MARK: - Status

@Test func validatorAccepts2xxAndRejectsTheRest() throws {
    let validator = DefaultStatusValidator()
    let url = URL(string: "https://example.com")!
    let body = Data("nope".utf8)

    for status in [200, 201, 204, 299] {
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        try validator.validate(response, data: Data())
    }

    for status in [199, 300, 400, 500] {
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        let error = try #require(throws: NetworkError.self) {
            try validator.validate(response, data: body)
        }
        guard case .httpError(let code, let data, _) = error else {
            Issue.record("expected httpError")
            return
        }
        #expect(code == status)
        #expect(data == body)
    }
}

// MARK: - Request building

@Test func buildsURLFromBasePathAndQuery() async throws {
    let capture = RequestCapture()
    let service = makeService(
        transport: StubTransport(
            data: Data("{}".utf8),
            capture: capture
        )
    )

    try await service.request(
        Endpoint<Void>(
            path: "/users/42/posts",
            method: .get,
            queryItems: [
                URLQueryItem(name: "q", value: "a b"),
                URLQueryItem(name: "id", value: "1"),
                URLQueryItem(name: "id", value: "2"),
            ]
        )
    )

    let request = await capture.request
    #expect(request?.httpMethod == "GET")
    #expect(
        request?.url?.absoluteString
            == "https://api.example.com/v1/users/42/posts?q=a%20b&id=1&id=2"
    )
}

@Test func encodesPathSeparatorsAsOneComponent() async throws {
    let capture = RequestCapture()
    let service = makeService(transport: StubTransport(capture: capture))

    try await service.request(
        Endpoint<Void>(
            path: "nyct/gtfs-ace",
            method: .get,
            encodesPathSeparators: true
        )
    )

    let request = await capture.request
    #expect(
        request?.url?.absoluteString
            == "https://api.example.com/v1/nyct%2Fgtfs-ace"
    )
}

@Test func emptyPathDoesNotAddTrailingSlash() async throws {
    let capture = RequestCapture()
    let service = makeService(transport: StubTransport(capture: capture))

    try await service.request(Endpoint<Void>(path: "", method: .get))

    let request = await capture.request
    #expect(request?.url?.absoluteString == "https://api.example.com/v1")
}

@Test func trailingSlashOnBaseURLStillJoins() async throws {
    let capture = RequestCapture()
    let service = makeService(
        baseURL: URL(string: "https://api.example.com/v1/")!,
        transport: StubTransport(capture: capture)
    )

    try await service.request(Endpoint<Void>(path: "users", method: .get))

    let request = await capture.request
    #expect(request?.url?.absoluteString == "https://api.example.com/v1/users")
}

@Test func endpointHeadersOverrideDefaultsIgnoringCase() async throws {
    let capture = RequestCapture()
    let service = makeService(
        defaultHeaders: HTTPHeaders([
            "Authorization": "Bearer old",
            "Accept": "application/json",
        ]),
        transport: StubTransport(capture: capture)
    )

    try await service.request(
        Endpoint<Void>(
            path: "users",
            method: .get,
            headers: HTTPHeaders(["authorization": "Bearer new"])
        )
    )

    let request = await capture.request
    #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer new")
    #expect(request?.value(forHTTPHeaderField: "Accept") == "application/json")
}

@Test func jsonFactoryEncodesEncodableValue() throws {
    struct Payload: Encodable {
        let id: Int
    }

    let body = try HTTPBody.json(Payload(id: 1))
    #expect(body.contentType == "application/json")
    #expect(body.data == Data(#"{"id":1}"#.utf8))
}

@Test func jsonBodySetsContentTypeWhenMissing() async throws {
    let capture = RequestCapture()
    let payload = Data(#"{"id":1}"#.utf8)
    let service = makeService(transport: StubTransport(capture: capture))

    try await service.request(
        Endpoint<Void>(
            path: "users",
            method: .post,
            body: .json(payload)
        )
    )

    let request = await capture.request
    #expect(request?.httpMethod == "POST")
    #expect(request?.httpBody == payload)
    #expect(request?.value(forHTTPHeaderField: "Content-Type") == "application/json")
}

@Test func explicitContentTypeIsNotOverwrittenByBody() async throws {
    let capture = RequestCapture()
    let service = makeService(
        defaultHeaders: HTTPHeaders(["Content-Type": "application/json; charset=utf-8"]),
        transport: StubTransport(capture: capture)
    )

    try await service.request(
        Endpoint<Void>(
            path: "users",
            method: .post,
            body: .json(Data(#"{}"#.utf8))
        )
    )

    let request = await capture.request
    #expect(
        request?.value(forHTTPHeaderField: "Content-Type")
            == "application/json; charset=utf-8"
    )
}

@Test func rawBodyWithoutContentTypeDoesNotInventOne() async throws {
    let capture = RequestCapture()
    let service = makeService(transport: StubTransport(capture: capture))

    try await service.request(
        Endpoint<Void>(
            path: "users",
            method: .post,
            body: .raw(Data("x".utf8), contentType: nil)
        )
    )

    let request = await capture.request
    #expect(request?.httpBody == Data("x".utf8))
    #expect(request?.value(forHTTPHeaderField: "Content-Type") == nil)
}

@Test func endpointContentTypeOverridesDefaultAndBody() async throws {
    let capture = RequestCapture()
    let service = makeService(
        defaultHeaders: HTTPHeaders([
            "Content-Type": "text/plain",
        ]),
        transport: StubTransport(capture: capture)
    )

    try await service.request(
        Endpoint<Void>(
            path: "users",
            method: .post,
            headers: HTTPHeaders([
                "content-type": "application/merge-patch+json",
            ]),
            body: .json(Data(#"{}"#.utf8))
        )
    )

    let request = await capture.request
    #expect(
        request?.value(forHTTPHeaderField: "Content-Type")
            == "application/merge-patch+json"
    )
}

@Test func timeoutIntervalIsCopiedOntoTheRequest() async throws {
    let capture = RequestCapture()
    let service = makeService(transport: StubTransport(capture: capture))

    try await service.request(
        Endpoint<Void>(
            path: "users",
            method: .get,
            timeoutInterval: 12
        )
    )

    let request = await capture.request
    #expect(request?.timeoutInterval == 12)
}

@Test func omittedTimeoutKeepsTheURLRequestDefault() async throws {
    let capture = RequestCapture()
    let service = makeService(transport: StubTransport(capture: capture))

    try await service.request(Endpoint<Void>(path: "users", method: .get))

    let request = await capture.request
    #expect(request?.timeoutInterval == 60)
}

@Test func getWithoutBodyDoesNotSetHTTPBody() async throws {
    let capture = RequestCapture()
    let service = makeService(transport: StubTransport(capture: capture))

    try await service.request(Endpoint<Void>(path: "users", method: .get))

    let request = await capture.request
    #expect(request?.httpBody == nil)
}

// MARK: - Pipeline

@Test func customDecoderConvertsSnakeCaseKeys() async throws {
    struct Profile: Decodable, Equatable, Sendable {
        let firstName: String
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let service = makeService(
        transport: StubTransport(
            data: Data(#"{"first_name":"Ada"}"#.utf8)
        ),
        decoder: JSONResponseDecoder(decoder: decoder)
    )

    let profile: Profile = try await service.request(
        Endpoint(path: "profile", method: .get)
    )
    #expect(profile == Profile(firstName: "Ada"))
}

@Test func customValidatorAcceptsStatusOutside2xx() async throws {
    struct AcceptNotModified: HTTPStatusValidator {
        func validate(
            _ response: HTTPURLResponse,
            data: Data
        ) throws {
            if response.statusCode == 304
                || (200...299).contains(response.statusCode) {
                return
            }
            throw NetworkError.httpError(
                statusCode: response.statusCode,
                data: data,
                response: response
            )
        }
    }

    let accepted = makeService(
        transport: StubTransport(data: Data(), statusCode: 304),
        validator: AcceptNotModified()
    )
    try await accepted.request(
        Endpoint<Void>(path: "users/1", method: .get)
    )

    let body = Data("nope".utf8)
    let rejected = makeService(
        transport: StubTransport(data: body, statusCode: 400),
        validator: AcceptNotModified()
    )
    let error = try await #require(throws: NetworkError.self) {
        try await rejected.request(
            Endpoint<Void>(path: "users/1", method: .get)
        )
    }
    guard case .httpError(let code, let data, _) = error else {
        Issue.record("expected httpError")
        return
    }
    #expect(code == 400)
    #expect(data == body)
}

@Test func decodesJSONAfterSuccess() async throws {
    let service = makeService(
        transport: StubTransport(
            data: Data(#"{"id":7}"#.utf8),
            statusCode: 200
        )
    )

    let user: User = try await service.request(
        Endpoint(path: "users/7", method: .get)
    )
    #expect(user == User(id: 7))
}

@Test func httpErrorKeepsStatusAndBodyAndDoesNotDecode() async throws {
    let body = Data(#"{"error":"nope"}"#.utf8)
    let service = makeService(
        transport: StubTransport(data: body, statusCode: 400)
    )

    let error = try await #require(throws: NetworkError.self) {
        try await service.request(
            Endpoint<User>(path: "users", method: .get)
        )
    }
    guard case .httpError(let code, let data, let response) = error else {
        Issue.record("expected httpError")
        return
    }
    #expect(code == 400)
    #expect(data == body)
    #expect(response.statusCode == 400)
}

@Test func requestWithResponseIncludesValueStatusAndHeaders() async throws {
    let body = Data(#"{"id":7}"#.utf8)
    let service = makeService(
        transport: StubTransport(
            data: body,
            statusCode: 201,
            headerFields: [
                "ETag": "\"abc\"",
                "X-RateLimit-Remaining": "9",
            ]
        )
    )

    let response: NetworkResponse<User> = try await service.requestWithResponse(
        Endpoint(path: "users/7", method: .get)
    )
    #expect(response.value == User(id: 7))
    #expect(response.statusCode == 201)
    #expect(response.headers.value(for: "ETag") == "\"abc\"")
    #expect(response.headers.value(for: "X-RateLimit-Remaining") == "9")
    #expect(response.data == body)
    #expect(response.response.statusCode == 201)
}

@Test func requestWithResponseOnVoidKeepsStatusAndHeaders() async throws {
    let service = makeService(
        transport: StubTransport(
            data: Data(),
            statusCode: 204,
            headerFields: [
                "ETag": "\"abc\"",
                "Location": "https://api.example.com/v1/users/1",
            ]
        )
    )

    let response: NetworkResponse<Void> = try await service.requestWithResponse(
        Endpoint<Void>(path: "users/1", method: .delete)
    )
    #expect(response.statusCode == 204)
    #expect(response.headers.value(for: "ETag") == "\"abc\"")
    #expect(
        response.headers.value(for: "Location")
            == "https://api.example.com/v1/users/1"
    )
    #expect(response.data.isEmpty)
}

@Test func requestWithResponseStillThrowsHTTPError() async throws {
    let body = Data(#"{"error":"nope"}"#.utf8)
    let service = makeService(
        transport: StubTransport(data: body, statusCode: 400)
    )

    let error = try await #require(throws: NetworkError.self) {
        try await service.requestWithResponse(
            Endpoint<User>(path: "users", method: .get)
        )
    }
    guard case .httpError(let code, let data, _) = error else {
        Issue.record("expected httpError")
        return
    }
    #expect(code == 400)
    #expect(data == body)
}

@Test func emptySuccessDoesNotDecodeOnVoidEndpoint() async throws {
    let service = makeService(
        transport: StubTransport(data: Data(), statusCode: 204)
    )

    try await service.request(
        Endpoint<Void>(path: "users/1", method: .delete)
    )
}

@Test func emptySuccessFailsWhenDecodingAModel() async throws {
    let service = makeService(
        transport: StubTransport(data: Data(), statusCode: 204)
    )

    await #expect(throws: DecodingError.self) {
        try await service.request(
            Endpoint<User>(path: "users/1", method: .delete)
        )
    }
}

@Test func invalidJSONThrowsDecodingError() async throws {
    let service = makeService(
        transport: StubTransport(data: Data("not json".utf8), statusCode: 200)
    )

    await #expect(throws: DecodingError.self) {
        try await service.request(
            Endpoint<User>(path: "users", method: .get)
        )
    }
}

@Test func transportErrorsPropagate() async throws {
    let service = makeService(
        transport: FailingTransport(error: NetworkError.invalidResponse)
    )

    let error = try await #require(throws: NetworkError.self) {
        try await service.request(Endpoint<Void>(path: "users", method: .get))
    }
    guard case .invalidResponse = error else {
        Issue.record("expected invalidResponse")
        return
    }
}
