import Foundation

public actor UpdateClient {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let baseURL: URL
    private let apiToken: String
    private let app: String
    private let channel: String
    private let installID: String
    private let store: UpdateStore
    private let transport: Transport

    public init(
        baseURL: URL,
        apiToken: String,
        app: String,
        channel: String = "production",
        installID: String,
        store: UpdateStore,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.baseURL = baseURL
        self.apiToken = apiToken
        self.app = app
        self.channel = channel
        self.installID = installID
        self.store = store
        self.transport = transport
    }

    @discardableResult
    public func checkForUpdate() async throws -> VerifiedUpdate? {
        var request = URLRequest(url: try endpoint("resolve", query: [URLQueryItem(name: "install_id", value: installID)]))
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport(request)
        let status = try statusCode(response)
        if status == 204 { return nil }
        guard status == 200 else { throw UpdateClientError.serverRejected(status, String(decoding: data, as: UTF8.self)) }

        let resolution = try JSONDecoder().decode(RemoteResolution.self, from: data)
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("PororocaRemote-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        try ManifestCodec.encode(resolution.update.manifest)
            .write(to: temporary.appendingPathComponent(UpdateBundle.manifestFilename), options: .atomic)

        for (path, encoded) in resolution.update.files {
            guard let bytes = Data(base64Encoded: encoded) else { throw UpdateClientError.invalidBase64(path) }
            let fileURL = try safeFileURL(path, root: temporary)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: fileURL, options: .atomic)
        }

        let verified = try await store.stage(bundleAt: temporary)
        try? await record(event: "downloaded", updateID: verified.manifest.updateID)
        return verified
    }

    public func record(event: String, updateID: String? = nil, metadata: [String: String] = [:]) async throws {
        var request = URLRequest(url: try endpoint("events"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RemoteEvent(
                installID: installID,
                event: event,
                updateID: updateID,
                occurredAt: ISO8601DateFormatter().string(from: Date()),
                metadata: metadata
            )
        )

        let (data, response) = try await transport(request)
        let status = try statusCode(response)
        guard status == 202 else { throw UpdateClientError.serverRejected(status, String(decoding: data, as: UTF8.self)) }
    }

    private func endpoint(_ action: String, query: [URLQueryItem] = []) throws -> URL {
        var url = baseURL
        for component in ["api", "v1", "apps", app, "channels", channel, action] {
            url.appendPathComponent(component)
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw UpdateClientError.invalidServerURL
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let result = components.url else { throw UpdateClientError.invalidServerURL }
        return result
    }

    private func statusCode(_ response: URLResponse) throws -> Int {
        guard let http = response as? HTTPURLResponse else { throw UpdateClientError.invalidResponse }
        return http.statusCode
    }

    private func safeFileURL(_ path: String, root: URL) throws -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("\\"),
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else { throw UpdateClientError.unsafePath(path) }
        return root.appendingPathComponent(path)
    }
}

public enum UpdateClientError: Error, Equatable {
    case invalidServerURL
    case invalidResponse
    case serverRejected(Int, String)
    case invalidBase64(String)
    case unsafePath(String)
}

private struct RemoteResolution: Decodable {
    var update: RemoteUpdate
}

private struct RemoteUpdate: Decodable {
    var manifest: SignedUpdateManifest
    var files: [String: String]
}

private struct RemoteEvent: Encodable {
    var installID: String
    var event: String
    var updateID: String?
    var occurredAt: String
    var metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case installID = "install_id"
        case event
        case updateID = "update_id"
        case occurredAt = "occurred_at"
        case metadata
    }
}
