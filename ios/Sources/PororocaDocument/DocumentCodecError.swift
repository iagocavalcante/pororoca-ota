import PororocaExpr

/// A structural or value error in a screen document.
public struct DocumentCodecError: Error, Equatable, Sendable {
    public enum Code: String, Sendable {
        case unknownKind
        case childCount
        case unexpectedChildren
        case invalidValue
    }

    public let code: Code
    public let path: JSONPath
    public let detail: String

    public init(code: Code, path: JSONPath, detail: String) {
        self.code = code; self.path = path; self.detail = detail
    }
}

func invalidValue(_ decoder: Decoder, _ value: String) -> DocumentCodecError {
    DocumentCodecError(code: .invalidValue, path: JSONPath(codingPath: decoder.codingPath), detail: value)
}

func decodeStringEnum<E: RawRepresentable>(_ type: E.Type, from decoder: Decoder) throws -> E where E.RawValue == String {
    let raw = try decoder.singleValueContainer().decode(String.self)
    guard let value = E(rawValue: raw) else { throw invalidValue(decoder, raw) }
    return value
}
