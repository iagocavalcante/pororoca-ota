import Foundation
import PororocaDocument

public struct VerifiedUpdate: Equatable, Sendable {
    public let manifest: UpdateManifest
    public let rootURL: URL

    public init(manifest: UpdateManifest, rootURL: URL) {
        self.manifest = manifest
        self.rootURL = rootURL
    }

    public func documentURL(for screen: String) -> URL? {
        guard let entry = manifest.documents.first(where: { $0.screen == screen }) else { return nil }
        return rootURL.appendingPathComponent(entry.path)
    }

}

public enum UpdateBundle {
    public static let manifestFilename = "manifest.json"

    public static func verify(
        at rootURL: URL,
        publicKey: Data,
        hostCapabilities: [String: HostCapabilities] = [:]
    ) throws -> VerifiedUpdate {
        let manifestURL = rootURL.appendingPathComponent(manifestFilename)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw UpdateError.missingFile(Self.manifestFilename)
        }
        let signed = try ManifestCodec.decode(Data(contentsOf: manifestURL))
        try UpdateCrypto.verify(signed, publicKey: publicKey)

        var requiredAssets = Set<String>()
        for entry in signed.manifest.documents {
            let url = try containedURL(entry.path, root: rootURL)
            guard FileManager.default.fileExists(atPath: url.path) else { throw UpdateError.missingFile(entry.path) }
            let data = try Data(contentsOf: url)
            try verifyHash(data, path: entry.path, expected: entry.sha256)
            let document = try DocumentCodec.decode(data)
            guard document.screen == entry.screen else {
                throw UpdateError.documentMismatch("manifest screen \(entry.screen), document screen \(document.screen)")
            }
            guard document.platform == signed.manifest.platform else {
                throw UpdateError.documentMismatch("\(entry.path) has platform \(document.platform.rawValue)")
            }
            guard document.requires == entry.requires else {
                throw UpdateError.documentMismatch("requires differ for \(entry.path)")
            }
            let errors = Validator.validate(document, against: hostCapabilities[document.screen])
            guard errors.isEmpty else {
                throw UpdateError.invalidDocument(path: entry.path, errors: errors.map(Self.describe))
            }
            requiredAssets.formUnion(document.requires.assets)
        }

        for entry in signed.manifest.assets {
            let url = try containedURL(entry.path, root: rootURL)
            guard FileManager.default.fileExists(atPath: url.path) else { throw UpdateError.missingFile(entry.path) }
            let data = try Data(contentsOf: url)
            guard data.count == entry.byteCount else {
                throw UpdateError.malformedManifest("byte count mismatch for \(entry.path)")
            }
            try verifyHash(data, path: entry.path, expected: entry.sha256)
        }
        let availableAssets = Set(signed.manifest.assets.map(\.sha256))
        if let missing = requiredAssets.first(where: { !availableAssets.contains($0) }) {
            throw UpdateError.missingFile(missing)
        }

        return VerifiedUpdate(manifest: signed.manifest, rootURL: rootURL)
    }

    public static func signedManifest(at rootURL: URL) throws -> SignedUpdateManifest {
        try ManifestCodec.decode(Data(contentsOf: rootURL.appendingPathComponent(manifestFilename)))
    }

    private static func verifyHash(_ data: Data, path: String, expected: String) throws {
        let actual = UpdateCrypto.sha256(data)
        guard actual == expected else { throw UpdateError.hashMismatch(path: path, expected: expected, actual: actual) }
    }

    private static func describe(_ error: ValidationError) -> String {
        "\(error.code.rawValue) \(error.path.pointer): \(error.detail)"
    }

    private static func containedURL(_ path: String, root: URL) throws -> URL {
        try UpdateManifest.validate(path: path)
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let resolved = root.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.path.hasPrefix(resolvedRoot.path + "/") else { throw UpdateError.unsafePath(path) }
        return resolved
    }
}
