/// An unknown key encountered by a strict keyed decoder.
public struct StrictDecodingError: Error, Equatable, Sendable {
    public let path: JSONPath
    public let key: String

    public init(path: JSONPath, key: String) {
        self.path = path
        self.key = key
    }
}

public extension Decoder {
    /// Returns a keyed container after rejecting keys outside the declared coding keys.
    func strictContainer<Key: CodingKey & CaseIterable>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let raw = try container(keyedBy: AnyCodingKey.self)
        let allowed = Set(Key.allCases.map(\.stringValue))
        if let unknown = raw.allKeys.map(\.stringValue).filter({ !allowed.contains($0) }).sorted().first {
            throw StrictDecodingError(path: JSONPath(codingPath: codingPath).appending(unknown), key: unknown)
        }
        return try container(keyedBy: type)
    }
}

public extension KeyedDecodingContainer {
    /// Returns a strict nested keyed container after rejecting unknown keys.
    func strictNestedContainer<Nested: CodingKey & CaseIterable>(
        keyedBy type: Nested.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<Nested> {
        let decoder = try superDecoder(forKey: key)
        return try decoder.strictContainer(keyedBy: type)
    }
}
