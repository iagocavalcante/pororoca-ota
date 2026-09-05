import Foundation
import PororocaDocument

public enum UpdateSelection: Equatable, Sendable {
    case embedded
    case update(VerifiedUpdate)
}

public struct BadUpdate: Codable, Equatable, Sendable {
    public var updateID: String
    public var reason: String

    public init(updateID: String, reason: String) {
        self.updateID = updateID
        self.reason = reason
    }
}

public actor UpdateStore {
    public let rootURL: URL
    private let publicKey: Data
    private let hostCapabilities: [String: HostCapabilities]

    public init(rootURL: URL, publicKey: Data, hostCapabilities: [String: HostCapabilities] = [:]) {
        self.rootURL = rootURL
        self.publicKey = publicKey
        self.hostCapabilities = hostCapabilities
    }

    public func stage(bundleAt sourceURL: URL) throws -> VerifiedUpdate {
        try ensureRoot()
        let verified = try UpdateBundle.verify(at: sourceURL, publicKey: publicKey, hostCapabilities: hostCapabilities)
        guard !badUpdates().contains(where: { $0.updateID == verified.manifest.updateID }) else {
            throw UpdateError.updateMarkedBad(verified.manifest.updateID)
        }

        let incoming = rootURL.appendingPathComponent(".incoming-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: incoming) }
        try FileManager.default.copyItem(at: sourceURL, to: incoming)
        _ = try UpdateBundle.verify(at: incoming, publicKey: publicKey, hostCapabilities: hostCapabilities)
        try replaceDirectory(at: pendingURL, with: incoming)
        return VerifiedUpdate(manifest: verified.manifest, rootURL: pendingURL)
    }

    public func prepareForLaunch() throws -> UpdateSelection {
        try ensureRoot()
        try recoverInterruptedPromotion()
        try recoverFailedLaunch()
        if FileManager.default.fileExists(atPath: pendingURL.path) { try promotePending() }
        guard FileManager.default.fileExists(atPath: currentURL.path) else { return .embedded }

        do {
            return .update(try UpdateBundle.verify(at: currentURL, publicKey: publicKey, hostCapabilities: hostCapabilities))
        } catch {
            let id = (try? UpdateBundle.signedManifest(at: currentURL).manifest.updateID) ?? "unknown-\(UUID().uuidString)"
            try markBad(id, reason: "current bundle verification failed: \(error)")
            try? FileManager.default.removeItem(at: currentURL)
            try? FileManager.default.removeItem(at: markerURL)
            if FileManager.default.fileExists(atPath: previousURL.path) {
                try FileManager.default.moveItem(at: previousURL, to: currentURL)
                return try prepareForLaunch()
            }
            return .embedded
        }
    }

    public func markLaunchSuccessful() throws {
        guard let marker = try read(LaunchMarker.self, at: markerURL), marker.status == .applying else {
            throw UpdateError.noApplyingUpdate
        }
        try write(LaunchMarker(updateID: marker.updateID, status: .good), to: markerURL)
    }

    public func rollbackToEmbedded() throws {
        for url in [pendingURL, currentURL, previousURL] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try? FileManager.default.removeItem(at: markerURL)
        try? FileManager.default.removeItem(at: transactionURL)
    }

    public func badUpdates() -> [BadUpdate] {
        (try? read([BadUpdate].self, at: badURL)) ?? []
    }

    public func pendingUpdateID() -> String? {
        try? UpdateBundle.signedManifest(at: pendingURL).manifest.updateID
    }

    private func promotePending() throws {
        let pendingID = try UpdateBundle.signedManifest(at: pendingURL).manifest.updateID
        try write(Promotion(updateID: pendingID), to: transactionURL)
        try write(LaunchMarker(updateID: pendingID, status: .applying), to: markerURL)

        if FileManager.default.fileExists(atPath: previousURL.path) { try FileManager.default.removeItem(at: previousURL) }
        if FileManager.default.fileExists(atPath: currentURL.path) {
            try FileManager.default.moveItem(at: currentURL, to: previousURL)
        }
        try FileManager.default.moveItem(at: pendingURL, to: currentURL)
        try FileManager.default.removeItem(at: transactionURL)
    }

    private func recoverInterruptedPromotion() throws {
        guard let transaction = try read(Promotion.self, at: transactionURL) else { return }
        let hasPending = FileManager.default.fileExists(atPath: pendingURL.path)
        let hasCurrent = FileManager.default.fileExists(atPath: currentURL.path)

        if hasPending {
            if hasCurrent {
                if FileManager.default.fileExists(atPath: previousURL.path) { try FileManager.default.removeItem(at: previousURL) }
                try FileManager.default.moveItem(at: currentURL, to: previousURL)
            }
            try FileManager.default.moveItem(at: pendingURL, to: currentURL)
        } else if !hasCurrent, FileManager.default.fileExists(atPath: previousURL.path) {
            try FileManager.default.moveItem(at: previousURL, to: currentURL)
            try? FileManager.default.removeItem(at: markerURL)
        }

        _ = transaction
        try FileManager.default.removeItem(at: transactionURL)
    }

    private func recoverFailedLaunch() throws {
        guard let marker = try read(LaunchMarker.self, at: markerURL), marker.status == .applying else { return }
        let currentID = try? UpdateBundle.signedManifest(at: currentURL).manifest.updateID
        if currentID == marker.updateID {
            try markBad(marker.updateID, reason: "previous launch did not reach the good marker")
            try? FileManager.default.removeItem(at: currentURL)
            if FileManager.default.fileExists(atPath: previousURL.path) {
                try FileManager.default.moveItem(at: previousURL, to: currentURL)
            }
        }
        try? FileManager.default.removeItem(at: markerURL)
    }

    private func markBad(_ updateID: String, reason: String) throws {
        var entries = badUpdates().filter { $0.updateID != updateID }
        entries.append(BadUpdate(updateID: updateID, reason: reason))
        try write(entries, to: badURL)
    }

    private func ensureRoot() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private func replaceDirectory(at destination: URL, with source: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    private func read<T: Decodable>(_ type: T.Type, at url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private var pendingURL: URL { rootURL.appendingPathComponent("pending", isDirectory: true) }
    private var currentURL: URL { rootURL.appendingPathComponent("current", isDirectory: true) }
    private var previousURL: URL { rootURL.appendingPathComponent("previous", isDirectory: true) }
    private var badURL: URL { rootURL.appendingPathComponent("bad.json") }
    private var markerURL: URL { rootURL.appendingPathComponent("launch-marker.json") }
    private var transactionURL: URL { rootURL.appendingPathComponent("promotion.json") }
}

private struct Promotion: Codable {
    var updateID: String
}

private struct LaunchMarker: Codable {
    enum Status: String, Codable { case applying, good }
    var updateID: String
    var status: Status
}
