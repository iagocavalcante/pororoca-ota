import Foundation
import PororocaDocument
import XCTest
@testable import PororocaUpdate

final class ManifestTests: XCTestCase {
    func testCanonicalManifestSigningIsDeterministic() throws {
        let key = UpdateCrypto.generateKeyPair()
        let manifest = fixtureManifest()
        let first = try UpdateCrypto.sign(manifest, privateKey: key.privateKey)
        let second = try UpdateCrypto.sign(manifest, privateKey: key.privateKey)

        XCTAssertEqual(first.manifest, second.manifest)
        XCTAssertEqual(first.keyID, second.keyID)
        XCTAssertEqual(try ManifestCodec.canonicalData(manifest), try ManifestCodec.canonicalData(manifest))
        XCTAssertNoThrow(try UpdateCrypto.verify(first, publicKey: key.publicKey))
        XCTAssertNoThrow(try UpdateCrypto.verify(second, publicKey: key.publicKey))
    }

    func testTamperingAndWrongKeyAreRejected() throws {
        let key = UpdateCrypto.generateKeyPair()
        var signed = try UpdateCrypto.sign(fixtureManifest(), privateKey: key.privateKey)
        signed.manifest.message = "tampered"

        XCTAssertThrowsError(try UpdateCrypto.verify(signed, publicKey: key.publicKey)) {
            XCTAssertEqual($0 as? UpdateError, .invalidSignature)
        }
        XCTAssertThrowsError(try UpdateCrypto.verify(signed, publicKey: UpdateCrypto.generateKeyPair().publicKey)) {
            guard case .keyIDMismatch = $0 as? UpdateError else { return XCTFail("unexpected error: \($0)") }
        }
    }

    func testStrictEnvelopeRejectsUnknownKeysAndUnsafePaths() throws {
        let key = UpdateCrypto.generateKeyPair()
        let encoded = try ManifestCodec.encode(UpdateCrypto.sign(fixtureManifest(), privateKey: key.privateKey))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["surprise"] = true
        XCTAssertThrowsError(try ManifestCodec.decode(JSONSerialization.data(withJSONObject: json)))

        var manifest = fixtureManifest()
        manifest.documents[0].path = "../outside.json"
        XCTAssertThrowsError(try ManifestCodec.canonicalData(manifest)) {
            XCTAssertEqual($0 as? UpdateError, .unsafePath("../outside.json"))
        }
    }

    func testHashIsStableAndNamesItsAlgorithm() {
        XCTAssertEqual(
            UpdateCrypto.sha256(Data("pororoca".utf8)),
            "sha256:c5a71c607ba5bf4419dafb7d88b8da24d69725e19a24b3c1da7662b74dd73b46"
        )
    }

    private func fixtureManifest() -> UpdateManifest {
        UpdateManifest(
            updateID: "update-1",
            platform: .ios,
            createdAt: "2026-09-03T22:00:00Z",
            gitSHA: "abc123",
            message: "Initial",
            documents: [
                UpdateDocument(
                    screen: "paywall",
                    path: "documents/paywall.json",
                    sha256: "sha256:" + String(repeating: "0", count: 64),
                    requires: Requires(runtime: "1")
                )
            ]
        )
    }
}
