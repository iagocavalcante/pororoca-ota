import Foundation
import Pororoca

struct SignedUpdateLaunch: Sendable {
    let store: UpdateStore?
    let documentURL: URL?
    let status: String
    let updateID: String?
}

enum SignedUpdateBootstrap {
    static let publicKeyFilename = "pororoca-public.key"
    static let incomingDirectoryName = "pororoca-incoming"
    static let storeDirectoryName = "PororocaOTA"

    static func prepare(
        documentsDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
        publicKey suppliedPublicKey: Data? = nil
    ) async -> SignedUpdateLaunch {
        do {
            let publicKey = try suppliedPublicKey ?? readKey(
                at: documentsDirectory.appendingPathComponent(publicKeyFilename)
            )
            let store = UpdateStore(
                rootURL: documentsDirectory.appendingPathComponent(storeDirectoryName, isDirectory: true),
                publicKey: publicKey,
                hostCapabilities: ["paywall": HostCapabilities(PaywallScreen.document.requires)]
            )
            let incoming = documentsDirectory.appendingPathComponent(incomingDirectoryName, isDirectory: true)
            var stagingStatus: String?
            if FileManager.default.fileExists(atPath: incoming.path) {
                do {
                    let staged = try await store.stage(bundleAt: incoming)
                    stagingStatus = "Staged \(staged.manifest.updateID)"
                    try FileManager.default.removeItem(at: incoming)
                } catch {
                    let rejected = try quarantine(incoming, under: documentsDirectory, error: error)
                    stagingStatus = "Rejected incoming update; preserved at \(rejected.lastPathComponent)"
                }
            }

            switch try await store.prepareForLaunch() {
            case .embedded:
                return SignedUpdateLaunch(
                    store: store,
                    documentURL: nil,
                    status: stagingStatus ?? "Using embedded paywall; no signed update is active",
                    updateID: nil
                )
            case let .update(update):
                return SignedUpdateLaunch(
                    store: store,
                    documentURL: update.documentURL(for: "paywall"),
                    status: [stagingStatus, "Active \(update.manifest.updateID)"].compactMap { $0 }.joined(separator: ". "),
                    updateID: update.manifest.updateID
                )
            }
        } catch {
            return SignedUpdateLaunch(
                store: nil,
                documentURL: nil,
                status: "Signed updates unavailable: \(error)",
                updateID: nil
            )
        }
    }

    private static func readKey(at url: URL) throws -> Data {
        let data = try Data(contentsOf: url)
        if data.count == 32 { return data }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decoded = Data(base64Encoded: text), decoded.count == 32 else {
            throw UpdateError.invalidKey(url.path)
        }
        return decoded
    }

    private static func quarantine(_ incoming: URL, under documents: URL, error: Error) throws -> URL {
        let rejectedRoot = documents.appendingPathComponent("PororocaRejected", isDirectory: true)
        try FileManager.default.createDirectory(at: rejectedRoot, withIntermediateDirectories: true)
        let destination = rejectedRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.moveItem(at: incoming, to: destination)
        try Data(String(describing: error).utf8).write(to: destination.appendingPathComponent("error.txt"), options: .atomic)
        return destination
    }
}
