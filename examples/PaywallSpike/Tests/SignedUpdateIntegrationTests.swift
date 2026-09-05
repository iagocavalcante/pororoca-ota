import Foundation
import Pororoca
import XCTest
@testable import PaywallSpike

final class SignedUpdateIntegrationTests: XCTestCase {
    func testSignedIncomingPaywallStagesAndApplies() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PaywallSignedUpdate-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let documents = root.appendingPathComponent("source")
        let incoming = root.appendingPathComponent(SignedUpdateBootstrap.incomingDirectoryName)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try DocumentCodec.encode(PaywallScreen.document).write(to: documents.appendingPathComponent("paywall.ios.json"))
        let key = UpdateCrypto.generateKeyPair()
        _ = try UpdateExporter.export(
            documentsAt: documents,
            to: incoming,
            updateID: "spike-one",
            platform: .ios,
            createdAt: "2026-09-03T22:00:00Z",
            privateKey: key.privateKey
        )

        let launch = await SignedUpdateBootstrap.prepare(documentsDirectory: root, publicKey: key.publicKey)

        XCTAssertEqual(launch.updateID, "spike-one")
        XCTAssertNotNil(launch.documentURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: incoming.path))
        try await launch.store?.markLaunchSuccessful()
    }

    func testTamperedIncomingPaywallIsQuarantined() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PaywallSignedUpdate-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let documents = root.appendingPathComponent("source")
        let incoming = root.appendingPathComponent(SignedUpdateBootstrap.incomingDirectoryName)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try DocumentCodec.encode(PaywallScreen.document).write(to: documents.appendingPathComponent("paywall.ios.json"))
        let key = UpdateCrypto.generateKeyPair()
        let exported = try UpdateExporter.export(
            documentsAt: documents,
            to: incoming,
            updateID: "tampered",
            platform: .ios,
            createdAt: "2026-09-03T22:00:00Z",
            privateKey: key.privateKey
        )
        let updateDocument = try XCTUnwrap(exported.documentURL(for: "paywall"))
        try Data("tampered".utf8).write(to: updateDocument)

        let launch = await SignedUpdateBootstrap.prepare(documentsDirectory: root, publicKey: key.publicKey)

        XCTAssertNil(launch.updateID)
        XCTAssertNil(launch.documentURL)
        XCTAssertTrue(launch.status.contains("Rejected incoming update"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: incoming.path))
    }
}
