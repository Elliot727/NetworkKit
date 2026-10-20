import Foundation

/// Case-insensitive HTTP header storage.
///
/// Names are lowercased on insert. `dictionary` therefore exposes lowercase
/// keys. When the same name is set twice with different casing, the later
/// value replaces the earlier one.
nonisolated
public struct HTTPHeaders: Sendable {

    private var values: [String: String]

    /// Creates headers from a dictionary. Keys are lowercased.
    public init(_ values: [String: String] = [:]) {
        self.values = values.reduce(into: [:]) { result, header in
            result[header.key.lowercased()] = header.value
        }
    }

    /// Creates headers from an `HTTPURLResponse`.
    ///
    /// Names are lowercased here. Non-string names are ignored. When two
    /// fields differ only by case, the later value replaces the earlier one.
    ///
    /// String values are copied unchanged. Numeric fields (`NSNumber`) use
    /// `stringValue`. Any other value is stored with `String(describing:)`.
    public init(_ response: HTTPURLResponse) {
        var values: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let name = key as? String else { continue }
            values[name.lowercased()] = Self.fieldValue(value)
        }
        self.values = values
    }

    /// Copies strings. `NSNumber` uses `stringValue`. Anything else uses
    /// `String(describing:)`.
    private static func fieldValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return String(describing: value)
    }

    /// Sets `value` for `name`, replacing any existing value for that name.
    public mutating func set(_ value: String, for name: String) {
        values[name.lowercased()] = value
    }

    /// Returns the value for `name`, ignoring case.
    public func value(for name: String) -> String? {
        values[name.lowercased()]
    }

    /// Snapshot of stored headers. Keys are lowercase.
    public var dictionary: [String: String] {
        values
    }
}
