import Foundation
import PororocaDocument
import XCTest
@testable import PororocaUpdate

final class UpdateBundleTests: XCTestCase {
    func testExporterCreatesAVerifiableContentAddressedBundle() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        try Data("image".utf8).write(to: sandbox.assets.appendingPathComponent("hero.png"))

        let verified = try sandbox.export(id: "one", key: key, assets: true)

        XCTAssertEqual(verified.manifest.updateID, "one")
        XCTAssertEqual(verified.manifest.documents.map(\.screen), ["paywall"])
        XCTAssertEqual(verified.manifest.assets.count, 1)
        XCTAssertNotNil(verified.documentURL(for: "paywall"))
        XCTAssertNoThrow(try UpdateBundle.verify(at: sandbox.bundle("one"), publicKey: key.publicKey))
    }

    func testIdenticalAssetsAreDeduplicatedByHash() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        try Data("same".utf8).write(to: sandbox.assets.appendingPathComponent("one.png"))
        try Data("same".utf8).write(to: sandbox.assets.appendingPathComponent("two.png"))

        let verified = try sandbox.export(id: "one", key: key, assets: true)

        XCTAssertEqual(verified.manifest.assets.count, 1)
    }

    func testDocumentHashMismatchIsRejected() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        let verified = try sandbox.export(id: "one", key: key)
        let documentURL = try XCTUnwrap(verified.documentURL(for: "paywall"))
        try Data("corrupt".utf8).write(to: documentURL)

        XCTAssertThrowsError(try UpdateBundle.verify(at: sandbox.bundle("one"), publicKey: key.publicKey)) {
            guard case .hashMismatch = $0 as? UpdateError else { return XCTFail("unexpected error: \($0)") }
        }
    }

    func testHostCapabilityMismatchRejectsBundle() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall", requires: Requires(runtime: "1", actions: ["purchase"]))
        _ = try sandbox.export(id: "one", key: key)
        let incompatible = HostCapabilities(runtime: "1")

        XCTAssertThrowsError(
            try UpdateBundle.verify(
                at: sandbox.bundle("one"),
                publicKey: key.publicKey,
                hostCapabilities: ["paywall": incompatible]
            )
        ) {
            guard case .invalidDocument = $0 as? UpdateError else { return XCTFail("unexpected error: \($0)") }
        }
    }

    func testRequiredAssetMustExistInBundle() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        let missingHash = "sha256:" + String(repeating: "a", count: 64)
        try sandbox.writeDocument(screen: "paywall", requires: Requires(runtime: "1", assets: [missingHash]))

        XCTAssertThrowsError(try sandbox.export(id: "one", key: key)) {
            XCTAssertEqual($0 as? UpdateError, .missingFile(missingHash))
        }
    }
}

struct Sandbox {
    let root: URL
    let documents: URL
    let assets: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("PororocaUpdateTests-\(UUID().uuidString)")
        documents = root.appendingPathComponent("documents")
        assets = root.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    }

    func writeDocument(screen: String, requires: Requires = Requires(runtime: "1")) throws {
        let document = Document(
            screen: screen,
            platform: .ios,
            requires: requires,
            root: Node(.text(value: .literal(screen)))
        )
        try DocumentCodec.encode(document).write(to: documents.appendingPathComponent("\(screen).ios.json"))
    }

    func export(id: String, key: UpdateKeyPair, assets includeAssets: Bool = false) throws -> VerifiedUpdate {
        try UpdateExporter.export(
            documentsAt: documents,
            assetsAt: includeAssets ? assets : nil,
            to: bundle(id),
            updateID: id,
            platform: .ios,
            createdAt: "2026-09-03T22:00:00Z",
            privateKey: key.privateKey
        )
    }

    func bundle(_ id: String) -> URL { root.appendingPathComponent("bundle-\(id)") }
    func store(_ id: String = "store") -> URL { root.appendingPathComponent(id) }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
