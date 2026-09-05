import PororocaExpr

/// A semantic error found while validating a document.
public struct ValidationError: Error, Equatable, Sendable {
    /// Stable validation error identifiers shared by tooling and runtimes.
    public enum Code: String, Sendable, CaseIterable {
        case unknownKey
        case unknownKind
        case unknownOperator
        case malformed
        case childCount
        case unexpectedChildren
        case invalidValue
        case unsupportedFormat
        case typeMismatch
        case undeclaredState
        case undeclaredLocal
        case itemOutsideForEach
        case undeclaredToken
        case undeclaredString
        case undeclaredAction
        case undeclaredSlot
        case undeclaredAsset
        case depthLimit
        case nodeLimit
        case negativeSize
        case invalidOpacity
        case overlappingPadding
        case capabilityMissing
    }

    /// The machine-readable error code.
    public let code: Code
    /// The exact JSON location of the error.
    public let path: JSONPath
    /// A concise description or missing-capability list.
    public let detail: String

    /// Creates a validation error.
    public init(code: Code, path: JSONPath, detail: String) {
        self.code = code
        self.path = path
        self.detail = detail
    }
}
