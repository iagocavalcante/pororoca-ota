/// A JSON-compatible runtime value.
public enum Value: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([Value])
    case object([String: Value])

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { self = .null; return }
        if let value = try? single.decode(Bool.self) { self = .bool(value); return }
        if let value = try? single.decode(Double.self) { self = .number(value); return }
        if let value = try? single.decode(String.self) { self = .string(value); return }
        if var values = try? decoder.unkeyedContainer() {
            var result: [Value] = []
            while !values.isAtEnd { result.append(try values.decode(Value.self)) }
            self = .array(result)
            return
        }
        let values = try decoder.container(keyedBy: AnyCodingKey.self)
        var result: [String: Value] = [:]
        for key in values.allKeys { result[key.stringValue] = try values.decode(Value.self, forKey: key) }
        self = .object(result)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer(); try container.encodeNil()
        case let .bool(value):
            var container = encoder.singleValueContainer(); try container.encode(value)
        case let .number(value):
            var container = encoder.singleValueContainer(); try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer(); try container.encode(value)
        case let .array(value):
            var container = encoder.singleValueContainer(); try container.encode(value)
        case let .object(value):
            var container = encoder.container(keyedBy: AnyCodingKey.self)
            for key in value.keys.sorted() {
                try container.encode(value[key], forKey: AnyCodingKey(stringValue: key))
            }
        }
    }
}

extension Value: ExpressibleByNilLiteral { public init(nilLiteral: ()) { self = .null } }
extension Value: ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool) { self = .bool(value) } }
extension Value: ExpressibleByIntegerLiteral { public init(integerLiteral value: Int) { self = .number(Double(value)) } }
extension Value: ExpressibleByFloatLiteral { public init(floatLiteral value: Double) { self = .number(value) } }
extension Value: ExpressibleByStringLiteral { public init(stringLiteral value: String) { self = .string(value) } }
extension Value: ExpressibleByArrayLiteral { public init(arrayLiteral elements: Value...) { self = .array(elements) } }
extension Value: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Value)...) { self = .object(Dictionary(uniqueKeysWithValues: elements)) }
}
