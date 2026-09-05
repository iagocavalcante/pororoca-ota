import Foundation

public enum ManifestCodec {
    public static func canonicalData(_ manifest: UpdateManifest) throws -> Data {
        try manifest.validateStructure()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(manifest)
    }

    public static func encode(_ signed: SignedUpdateManifest) throws -> Data {
        try signed.manifest.validateStructure()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(signed)
        data.append(0x0A)
        return data
    }

    public static func decode(_ data: Data) throws -> SignedUpdateManifest {
        do {
            try StrictManifestShape.validate(data)
            let signed = try JSONDecoder().decode(SignedUpdateManifest.self, from: data)
            try signed.manifest.validateStructure()
            return signed
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.malformedManifest(String(describing: error))
        }
    }
}

private enum StrictManifestShape {
    static func validate(_ data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UpdateError.malformedManifest("root must be an object")
        }
        try rejectUnknown(root, allowed: ["manifest", "keyID", "signature"], at: "/")
        guard let manifest = root["manifest"] as? [String: Any] else {
            throw UpdateError.malformedManifest("/manifest must be an object")
        }
        try rejectUnknown(
            manifest,
            allowed: ["format", "updateID", "platform", "createdAt", "gitSHA", "message", "documents", "assets"],
            at: "/manifest"
        )
        if let documents = manifest["documents"] as? [[String: Any]] {
            for (index, document) in documents.enumerated() {
                try rejectUnknown(document, allowed: ["screen", "path", "sha256", "requires"], at: "/manifest/documents/\(index)")
            }
        }
        if let assets = manifest["assets"] as? [[String: Any]] {
            for (index, asset) in assets.enumerated() {
                try rejectUnknown(asset, allowed: ["path", "sha256", "byteCount", "contentType"], at: "/manifest/assets/\(index)")
            }
        }
    }

    private static func rejectUnknown(_ object: [String: Any], allowed: Set<String>, at path: String) throws {
        if let key = object.keys.first(where: { !allowed.contains($0) }) {
            throw UpdateError.malformedManifest("unknown key \(path)/\(key)")
        }
    }
}
