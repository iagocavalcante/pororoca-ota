import Foundation
import PororocaDocument
import PororocaUpdate

@main
struct PororocaPublisherCLI {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("pororoca: \(error)\n".utf8))
            Foundation.exit(2)
        }
    }

    private static func run(_ arguments: [String]) async throws {
        guard let command = arguments.first else { throw CLIError.usage }
        let rest = Array(arguments.dropFirst())
        switch command {
        case "keys": try generateKeys(rest)
        case "validate": try validate(rest)
        case "export": try export(rest)
        case "publish": try await publish(rest)
        default: throw CLIError.unknownCommand(command)
        }
    }

    private static func generateKeys(_ arguments: [String]) throws {
        guard arguments.first == "generate", let output = option("--output", in: arguments) else {
            throw CLIError.usage
        }
        let directory = URL(fileURLWithPath: output).standardizedFileURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pair = UpdateCrypto.generateKeyPair()
        let privateURL = directory.appendingPathComponent("private.key")
        let publicURL = directory.appendingPathComponent("public.key")
        guard !FileManager.default.fileExists(atPath: privateURL.path),
              !FileManager.default.fileExists(atPath: publicURL.path)
        else { throw CLIError.outputExists(directory.path) }
        try Data((pair.privateKey.base64EncodedString() + "\n").utf8).write(to: privateURL, options: .atomic)
        try Data((pair.publicKey.base64EncodedString() + "\n").utf8).write(to: publicURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateURL.path)
        print("generated key \(pair.keyID)\nprivate: \(privateURL.path)\npublic:  \(publicURL.path)")
    }

    private static func validate(_ arguments: [String]) throws {
        guard let input = arguments.first else { throw CLIError.usage }
        let platform = try option("--platform", in: arguments).map(parsePlatform) ?? .ios
        let documents = try UpdateExporter.validateDocuments(
            at: URL(fileURLWithPath: input).standardizedFileURL,
            platform: platform
        )
        print("valid: \(documents.count) \(platform.rawValue) document(s)")
    }

    private static func export(_ arguments: [String]) throws {
        guard let input = arguments.first,
              let output = option("--output", in: arguments),
              let updateID = option("--update-id", in: arguments),
              let keyPath = option("--private-key", in: arguments)
        else { throw CLIError.usage }

        let platform = try option("--platform", in: arguments).map(parsePlatform) ?? .ios
        let key = try readKey(at: keyPath)
        let createdAt = option("--created-at", in: arguments) ?? ISO8601DateFormatter().string(from: Date())
        let outputURL = URL(fileURLWithPath: output).standardizedFileURL
        guard arguments.contains("--force") || !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw CLIError.outputExists(outputURL.path)
        }
        let update = try UpdateExporter.export(
            documentsAt: URL(fileURLWithPath: input).standardizedFileURL,
            assetsAt: option("--assets", in: arguments).map { URL(fileURLWithPath: $0).standardizedFileURL },
            to: outputURL,
            updateID: updateID,
            platform: platform,
            createdAt: createdAt,
            gitSHA: option("--git-sha", in: arguments),
            message: option("--message", in: arguments),
            privateKey: key
        )
        print("exported \(update.manifest.updateID): \(update.manifest.documents.count) document(s), \(update.manifest.assets.count) asset(s)")
    }

    private static func publish(_ arguments: [String]) async throws {
        if option("--server", in: arguments) != nil {
            try await publishRemote(arguments)
            return
        }

        guard let bundle = arguments.first,
              let storePath = option("--store", in: arguments),
              let keyPath = option("--public-key", in: arguments)
        else { throw CLIError.usage }
        let store = UpdateStore(
            rootURL: URL(fileURLWithPath: storePath).standardizedFileURL,
            publicKey: try readKey(at: keyPath)
        )
        let update = try await store.stage(bundleAt: URL(fileURLWithPath: bundle).standardizedFileURL)
        print("staged \(update.manifest.updateID) for next launch")
    }

    private static func publishRemote(_ arguments: [String]) async throws {
        guard let bundlePath = arguments.first,
              let server = option("--server", in: arguments),
              let app = option("--app", in: arguments),
              let publicKeyPath = option("--public-key", in: arguments),
              let token = option("--token", in: arguments) ?? ProcessInfo.processInfo.environment["POROROCA_API_TOKEN"]
        else { throw CLIError.usage }

        let bundleURL = URL(fileURLWithPath: bundlePath).standardizedFileURL
        let verified = try UpdateBundle.verify(at: bundleURL, publicKey: try readKey(at: publicKeyPath))
        let signed = try UpdateBundle.signedManifest(at: bundleURL)
        let channel = option("--channel", in: arguments) ?? "production"
        let rollout = option("--rollout", in: arguments).flatMap(Int.init) ?? 100
        guard (0 ... 100).contains(rollout) else { throw CLIError.invalidRollout(rollout) }

        var files: [String: String] = [:]
        for entry in signed.manifest.documents {
            files[entry.path] = try Data(contentsOf: bundleURL.appendingPathComponent(entry.path)).base64EncodedString()
        }
        for entry in signed.manifest.assets {
            files[entry.path] = try Data(contentsOf: bundleURL.appendingPathComponent(entry.path)).base64EncodedString()
        }

        let payload = RemotePublishRequest(
            externalID: signed.manifest.updateID,
            label: option("--label", in: arguments) ?? signed.manifest.message ?? signed.manifest.updateID,
            platform: signed.manifest.platform.rawValue,
            manifest: signed,
            files: files,
            rolloutPercentage: rollout
        )

        guard var endpoint = URL(string: server) else { throw CLIError.invalidServer(server) }
        for component in ["api", "v1", "apps", app, "channels", channel, "updates"] {
            endpoint.appendPathComponent(component)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CLIError.invalidServer(server) }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw CLIError.serverRejected(http.statusCode, String(decoding: data, as: UTF8.self))
        }

        print("published \(verified.manifest.updateID) to \(app)/\(channel) at \(rollout)%")
    }

    private static func option(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func parsePlatform(_ value: String) throws -> Platform {
        guard let platform = Platform(rawValue: value) else { throw CLIError.invalidPlatform(value) }
        return platform
    }

    private static func readKey(at path: String) throws -> Data {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        if data.count == 32 { return data }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decoded = Data(base64Encoded: text), decoded.count == 32 else { throw UpdateError.invalidKey(path) }
        return decoded
    }
}

private enum CLIError: Error, CustomStringConvertible {
    case usage
    case unknownCommand(String)
    case invalidPlatform(String)
    case outputExists(String)
    case invalidRollout(Int)
    case invalidServer(String)
    case serverRejected(Int, String)

    var description: String {
        switch self {
        case .usage:
            """
            usage:
              swift run pororoca keys generate --output <directory>
              swift run pororoca validate <documents> [--platform ios|android]
              swift run pororoca export <documents> --output <bundle> --update-id <id> --private-key <file> [--assets <directory>] [--platform ios|android] [--force]
              swift run pororoca publish <bundle> --store <directory> --public-key <file>
              swift run pororoca publish <bundle> --server <url> --app <slug> --public-key <file> [--channel production] [--rollout 10]
            """
        case let .unknownCommand(command): "unknown command: \(command)"
        case let .invalidPlatform(platform): "invalid platform: \(platform)"
        case let .outputExists(path): "output already exists: \(path) (pass --force when exporting to replace it)"
        case let .invalidRollout(value): "rollout must be between 0 and 100, got \(value)"
        case let .invalidServer(value): "invalid Pororoca server URL: \(value)"
        case let .serverRejected(status, body): "Pororoca server rejected the update (HTTP \(status)): \(body)"
        }
    }
}

private struct RemotePublishRequest: Encodable {
    let externalID: String
    let label: String
    let platform: String
    let manifest: SignedUpdateManifest
    let files: [String: String]
    let rolloutPercentage: Int

    enum CodingKeys: String, CodingKey {
        case externalID = "external_id"
        case label
        case platform
        case manifest
        case files
        case rolloutPercentage = "rollout_percentage"
    }
}
