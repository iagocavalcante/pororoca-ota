import Foundation
import PororocaDocument

public enum UpdateExporter {
    @discardableResult
    public static func export(
        documentsAt documentsURL: URL,
        assetsAt assetsURL: URL? = nil,
        to outputURL: URL,
        updateID: String,
        platform: Platform,
        createdAt: String,
        gitSHA: String? = nil,
        message: String? = nil,
        privateKey: Data
    ) throws -> VerifiedUpdate {
        let documents = try documentFiles(at: documentsURL).map { url -> (Document, Data) in
            let document = try DocumentCodec.decode(Data(contentsOf: url))
            let errors = Validator.validate(document)
            guard errors.isEmpty else {
                throw UpdateError.invalidDocument(path: url.path, errors: errors.map(describe))
            }
            guard document.platform == platform else {
                throw UpdateError.documentMismatch("\(url.lastPathComponent) is \(document.platform.rawValue), expected \(platform.rawValue)")
            }
            return (document, try DocumentCodec.encode(document))
        }.sorted { $0.0.screen < $1.0.screen }

        guard !documents.isEmpty else { throw UpdateError.malformedManifest("no .json documents found") }
        let pair = try UpdateCrypto.keyPair(privateKey: privateKey)
        let parent = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".export-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.createDirectory(at: staging.appendingPathComponent("documents"), withIntermediateDirectories: true)

        var entries: [UpdateDocument] = []
        for (document, data) in documents {
            let hash = UpdateCrypto.sha256(data)
            let path = "documents/\(hash.dropFirst("sha256:".count)).json"
            try data.write(to: staging.appendingPathComponent(path), options: Data.WritingOptions.atomic)
            entries.append(UpdateDocument(screen: document.screen, path: path, sha256: hash, requires: document.requires))
        }

        var assetsByHash: [String: UpdateAsset] = [:]
        if let assetsURL {
            try FileManager.default.createDirectory(at: staging.appendingPathComponent("assets"), withIntermediateDirectories: true)
            for url in try regularFiles(at: assetsURL) {
                let data = try Data(contentsOf: url)
                let hash = UpdateCrypto.sha256(data)
                let digest = hash.dropFirst("sha256:".count)
                let path = "assets/\(digest)"
                if assetsByHash[hash] == nil {
                    try data.write(to: staging.appendingPathComponent(path), options: .atomic)
                    assetsByHash[hash] = UpdateAsset(
                        path: path,
                        sha256: hash,
                        byteCount: data.count,
                        contentType: contentType(for: url.pathExtension)
                    )
                }
            }
        }
        let assets = assetsByHash.values.sorted { $0.path < $1.path }

        let manifest = UpdateManifest(
            updateID: updateID,
            platform: platform,
            createdAt: createdAt,
            gitSHA: gitSHA,
            message: message,
            documents: entries,
            assets: assets
        )
        let signed = try UpdateCrypto.sign(manifest, privateKey: privateKey)
        try ManifestCodec.encode(signed).write(
            to: staging.appendingPathComponent(UpdateBundle.manifestFilename),
            options: .atomic
        )
        _ = try UpdateBundle.verify(at: staging, publicKey: pair.publicKey)

        if FileManager.default.fileExists(atPath: outputURL.path) { try FileManager.default.removeItem(at: outputURL) }
        try FileManager.default.moveItem(at: staging, to: outputURL)
        return try UpdateBundle.verify(at: outputURL, publicKey: pair.publicKey)
    }

    public static func validateDocuments(at directory: URL, platform: Platform? = nil) throws -> [Document] {
        try documentFiles(at: directory).map { url in
            let data = try Data(contentsOf: url)
            let document = try DocumentCodec.decode(data)
            if let platform, document.platform != platform {
                throw UpdateError.documentMismatch("\(url.lastPathComponent) is \(document.platform.rawValue), expected \(platform.rawValue)")
            }
            let errors = Validator.validate(data)
            guard errors.isEmpty else {
                throw UpdateError.invalidDocument(path: url.path, errors: errors.map(describe))
            }
            return document
        }
    }

    private static func documentFiles(at directory: URL) throws -> [URL] {
        try regularFiles(at: directory).filter { $0.pathExtension.lowercased() == "json" }.sorted { $0.path < $1.path }
    }

    private static func regularFiles(at directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { throw UpdateError.missingFile(directory.path) }
        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL,
                  try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            else { return nil }
            return url
        }
    }

    private static func contentType(for pathExtension: String) -> String? {
        switch pathExtension.lowercased() {
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "webp": "image/webp"
        case "json": "application/json"
        default: nil
        }
    }

    private static func describe(_ error: ValidationError) -> String {
        "\(error.code.rawValue) \(error.path.pointer): \(error.detail)"
    }
}
