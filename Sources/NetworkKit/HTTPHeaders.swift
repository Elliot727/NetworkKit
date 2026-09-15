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
