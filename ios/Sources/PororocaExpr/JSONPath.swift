import Foundation

/// A type-erased coding key used by the strict JSON codecs.
public struct AnyCodingKey: CodingKey, Sendable, Hashable {
    public let stringValue: String
    public let intValue: Int?

    public init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// An RFC 6901-style path into a JSON value.
public struct JSONPath: Sendable, Hashable, CustomStringConvertible {
    public var segments: [String]

    public init(_ segments: [String]) {
        self.segments = segments
    }

    public init(codingPath: [any CodingKey]) {
        self.segments = codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
    }

    public var pointer: String {
        segments.map { "/" + $0.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1") }.joined()
    }

    public func appending(_ segment: String) -> JSONPath {
        JSONPath(segments + [segment])
    }

    public var description: String { pointer }
}
