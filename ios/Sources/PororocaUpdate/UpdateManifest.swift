import Foundation
import PororocaDocument

public struct UpdateManifest: Codable, Equatable, Sendable {
    public static let currentFormat = 1

    public var format: Int
    public var updateID: String
    public var platform: Platform
    public var createdAt: String
    public var gitSHA: String?
    public var message: String?
    public var documents: [UpdateDocument]
    public var assets: [UpdateAsset]

    public init(
        format: Int = Self.currentFormat,
        updateID: String,
        platform: Platform,
        createdAt: String,
        gitSHA: String? = nil,
        message: String? = nil,
        documents: [UpdateDocument],
        assets: [UpdateAsset] = []
    ) {
        self.format = format
        self.updateID = updateID
        self.platform = platform
        self.createdAt = createdAt
        self.gitSHA = gitSHA
        self.message = message
        self.documents = documents
        self.assets = assets
    }

    func validateStructure() throws {
        guard format == Self.currentFormat else { throw UpdateError.unsupportedManifestFormat(format) }
        let allowedIDScalars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._")
        guard !updateID.isEmpty, updateID.unicodeScalars.allSatisfy(allowedIDScalars.contains)
        else { throw UpdateError.invalidUpdateID(updateID) }
        guard !createdAt.isEmpty else { throw UpdateError.malformedManifest("createdAt is empty") }
        guard !documents.isEmpty else { throw UpdateError.malformedManifest("documents is empty") }

        var paths = Set<String>()
        var screens = Set<String>()
        for document in documents {
            guard !document.screen.isEmpty else { throw UpdateError.malformedManifest("document screen is empty") }
            try Self.validate(path: document.path)
            guard paths.insert(document.path).inserted else { throw UpdateError.duplicatePath(document.path) }
            guard screens.insert(document.screen).inserted else { throw UpdateError.duplicateScreen(document.screen) }
            guard Self.isSHA256(document.sha256) else {
                throw UpdateError.malformedManifest("invalid SHA-256 for \(document.path)")
            }
        }
        for asset in assets {
            try Self.validate(path: asset.path)
            guard paths.insert(asset.path).inserted else { throw UpdateError.duplicatePath(asset.path) }
            guard asset.byteCount >= 0 else { throw UpdateError.malformedManifest("negative byte count for \(asset.path)") }
            guard Self.isSHA256(asset.sha256) else {
                throw UpdateError.malformedManifest("invalid SHA-256 for \(asset.path)")
            }
        }
    }

    static func validate(path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("\\"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else { throw UpdateError.unsafePath(path) }
    }

    private static func isSHA256(_ value: String) -> Bool {
        guard value.hasPrefix("sha256:"), value.count == 71 else { return false }
        return value.dropFirst("sha256:".count).allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

public struct UpdateDocument: Codable, Equatable, Sendable {
    public var screen: String
    public var path: String
    public var sha256: String
    public var requires: Requires

    public init(screen: String, path: String, sha256: String, requires: Requires) {
        self.screen = screen
        self.path = path
        self.sha256 = sha256
        self.requires = requires
    }
}

public struct UpdateAsset: Codable, Equatable, Sendable {
    public var path: String
    public var sha256: String
    public var byteCount: Int
    public var contentType: String?

    public init(path: String, sha256: String, byteCount: Int, contentType: String? = nil) {
        self.path = path
        self.sha256 = sha256
        self.byteCount = byteCount
        self.contentType = contentType
    }
}

public struct SignedUpdateManifest: Codable, Equatable, Sendable {
    public var manifest: UpdateManifest
    public var keyID: String
    public var signature: String

    public init(manifest: UpdateManifest, keyID: String, signature: String) {
        self.manifest = manifest
        self.keyID = keyID
        self.signature = signature
    }
}
