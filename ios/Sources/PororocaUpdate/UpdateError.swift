import Foundation

public enum UpdateError: Error, Equatable, CustomStringConvertible, Sendable {
    case malformedManifest(String)
    case unsupportedManifestFormat(Int)
    case unsafePath(String)
    case duplicatePath(String)
    case duplicateScreen(String)
    case invalidUpdateID(String)
    case invalidKey(String)
    case invalidSignature
    case keyIDMismatch(expected: String, actual: String)
    case missingFile(String)
    case hashMismatch(path: String, expected: String, actual: String)
    case documentMismatch(String)
    case invalidDocument(path: String, errors: [String])
    case updateMarkedBad(String)
    case noApplyingUpdate

    public var description: String {
        switch self {
        case let .malformedManifest(detail): "malformed manifest: \(detail)"
        case let .unsupportedManifestFormat(format): "unsupported manifest format \(format)"
        case let .unsafePath(path): "unsafe relative path: \(path)"
        case let .duplicatePath(path): "duplicate manifest path: \(path)"
        case let .duplicateScreen(screen): "duplicate screen: \(screen)"
        case let .invalidUpdateID(id): "invalid update id: \(id)"
        case let .invalidKey(detail): "invalid signing key: \(detail)"
        case .invalidSignature: "manifest signature is invalid"
        case let .keyIDMismatch(expected, actual): "signing key id mismatch: expected \(expected), got \(actual)"
        case let .missingFile(path): "manifest file is missing: \(path)"
        case let .hashMismatch(path, expected, actual): "hash mismatch for \(path): expected \(expected), got \(actual)"
        case let .documentMismatch(detail): "document metadata mismatch: \(detail)"
        case let .invalidDocument(path, errors): "invalid document \(path): \(errors.joined(separator: ", "))"
        case let .updateMarkedBad(id): "update \(id) was previously marked bad"
        case .noApplyingUpdate: "there is no applying update to mark successful"
        }
    }
}
