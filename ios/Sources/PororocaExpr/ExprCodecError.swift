/// A structural error in an encoded expression.
public struct ExprCodecError: Error, Equatable, Sendable {
    public enum Code: String, Sendable {
        case unknownOperator
        case malformed
    }

    public let code: Code
    public let path: JSONPath
    public let detail: String

    public init(code: Code, path: JSONPath, detail: String) {
        self.code = code
        self.path = path
        self.detail = detail
    }
}
