import Foundation
import XCTest
@testable import PororocaUpdate

final class UpdateClientTests: XCTestCase {
    func testDownloadsVerifiesAndStagesResolvedUpdate() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        let bundle = try sandbox.export(id: "remote-one", key: key)
        let responseData = try remoteResponse(for: bundle.rootURL)
        let store = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)

        let client = UpdateClient(
            baseURL: try XCTUnwrap(URL(string: "https://ota.example")),
            apiToken: "pororoca_live_test",
            app: "trainer-gym-ai",
            installID: "install-00000001",
            store: store,
            transport: { request in
                let status = request.url?.path.hasSuffix("/resolve") == true ? 200 : 202
                let data = status == 200 ? responseData : Data(#"{"id":"event-1"}"#.utf8)
                return (data, try XCTUnwrap(HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)))
            }
        )

        let update = try await client.checkForUpdate()
        XCTAssertEqual(update?.manifest.updateID, "remote-one")
        let pendingID = await store.pendingUpdateID()
        XCTAssertEqual(pendingID, "remote-one")
    }

    func testNoContentMeansNoEligibleUpdate() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        let store = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)

        let client = UpdateClient(
            baseURL: try XCTUnwrap(URL(string: "https://ota.example")),
            apiToken: "pororoca_live_test",
            app: "trainer-gym-ai",
            installID: "install-00000002",
            store: store,
            transport: { request in
                (Data(), try XCTUnwrap(HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)))
            }
        )

        let update = try await client.checkForUpdate()
        XCTAssertNil(update)
    }

    func testRejectsNonLoopbackHTTPServer() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        let store = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)
        let client = UpdateClient(
            baseURL: try XCTUnwrap(URL(string: "http://ota.example")),
            apiToken: "pororoca_live_test",
            app: "trainer-gym-ai",
            installID: "install-00000002",
            store: store,
            transport: { _ in XCTFail("transport must not run"); throw UpdateClientError.invalidResponse }
        )

        do {
            _ = try await client.checkForUpdate()
            XCTFail("expected insecure URL rejection")
        } catch {
            XCTAssertEqual(error as? UpdateClientError, .insecureServerURL)
        }
    }

    private func remoteResponse(for bundleURL: URL) throws -> Data {
        let signed = try UpdateBundle.signedManifest(at: bundleURL)
        let manifestObject = try JSONSerialization.jsonObject(with: ManifestCodec.encode(signed))
        var files: [String: String] = [:]

        for entry in signed.manifest.documents {
            files[entry.path] = try Data(contentsOf: bundleURL.appendingPathComponent(entry.path)).base64EncodedString()
        }
        for entry in signed.manifest.assets {
            files[entry.path] = try Data(contentsOf: bundleURL.appendingPathComponent(entry.path)).base64EncodedString()
        }

        return try JSONSerialization.data(withJSONObject: [
            "update": ["manifest": manifestObject, "files": files]
        ])
    }
}
