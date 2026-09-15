import Foundation

/// `JSONDecoder` wrapper. Pass a configured decoder for date/key strategies.
nonisolated
public struct JSONResponseDecoder: ResponseDecoder {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func decode<T: Decodable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}
