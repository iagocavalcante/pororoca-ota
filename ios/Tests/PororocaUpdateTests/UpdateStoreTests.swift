import Foundation
import PororocaDocument
import XCTest
@testable import PororocaUpdate

final class UpdateStoreTests: XCTestCase {
    func testStagedUpdateAppliesOnNextLaunchAndBecomesGood() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        let bundle = try sandbox.export(id: "one", key: key)
        let store = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)

        _ = try await store.stage(bundleAt: bundle.rootURL)
        let pendingID = await store.pendingUpdateID()
        XCTAssertEqual(pendingID, "one")
        guard case let .update(selected) = try await store.prepareForLaunch() else {
            return XCTFail("expected update")
        }
        XCTAssertEqual(selected.manifest.updateID, "one")
        try await store.markLaunchSuccessful()

        guard case let .update(nextLaunch) = try await store.prepareForLaunch() else {
            return XCTFail("expected known-good update")
        }
        XCTAssertEqual(nextLaunch.manifest.updateID, "one")
    }

    func testFailedFirstUpdateFallsBackToEmbeddedAndIsQuarantined() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        let bundle = try sandbox.export(id: "bad-first", key: key)
        let store = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)

        _ = try await store.stage(bundleAt: bundle.rootURL)
        _ = try await store.prepareForLaunch()
        let recovered = try await store.prepareForLaunch()
        let badIDs = await store.badUpdates().map(\.updateID)
        XCTAssertEqual(recovered, .embedded)
        XCTAssertEqual(badIDs, ["bad-first"])

        await XCTAssertThrowsErrorAsync(try await store.stage(bundleAt: bundle.rootURL)) {
            XCTAssertEqual($0 as? UpdateError, .updateMarkedBad("bad-first"))
        }
    }

    func testFailedUpdateRestoresPreviousKnownGoodUpdate() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        let first = try sandbox.export(id: "one", key: key)
        let store = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)
        _ = try await store.stage(bundleAt: first.rootURL)
        _ = try await store.prepareForLaunch()
        try await store.markLaunchSuccessful()

        try sandbox.writeDocument(screen: "paywall")
        let second = try sandbox.export(id: "two", key: key)
        _ = try await store.stage(bundleAt: second.rootURL)
        _ = try await store.prepareForLaunch()

        guard case let .update(recovered) = try await store.prepareForLaunch() else {
            return XCTFail("expected previous update")
        }
        XCTAssertEqual(recovered.manifest.updateID, "one")
        let badIDs = await store.badUpdates().map(\.updateID)
        XCTAssertEqual(badIDs, ["two"])
    }

    func testInvalidBundleNeverReplacesPending() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        let valid = try sandbox.export(id: "valid", key: key)
        let store = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)
        _ = try await store.stage(bundleAt: valid.rootURL)

        let incomplete = sandbox.bundle("incomplete")
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
        await XCTAssertThrowsErrorAsync(try await store.stage(bundleAt: incomplete))
        let pendingID = await store.pendingUpdateID()
        XCTAssertEqual(pendingID, "valid")
    }

    func testIncompatiblePromotedUpdateFallsBackWithoutLeavingApplyingMarker() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(
            screen: "paywall",
            requires: Requires(runtime: "1", actions: ["purchase"])
        )
        let bundle = try sandbox.export(id: "incompatible", key: key)
        let stagingStore = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)
        _ = try await stagingStore.stage(bundleAt: bundle.rootURL)
        let appStore = UpdateStore(
            rootURL: sandbox.store(),
            publicKey: key.publicKey,
            hostCapabilities: ["paywall": HostCapabilities(runtime: "1")]
        )

        let selection = try await appStore.prepareForLaunch()
        XCTAssertEqual(selection, .embedded)
        let badIDs = await appStore.badUpdates().map(\.updateID)
        XCTAssertEqual(badIDs, ["incompatible"])
        await XCTAssertThrowsErrorAsync(try await appStore.markLaunchSuccessful()) {
            XCTAssertEqual($0 as? UpdateError, .noApplyingUpdate)
        }
    }

    func testInterruptedPromotionRestoresPreviousKnownGoodUpdate() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        let first = try sandbox.export(id: "one", key: key)
        let storeRoot = sandbox.store()
        let store = UpdateStore(rootURL: storeRoot, publicKey: key.publicKey)
        _ = try await store.stage(bundleAt: first.rootURL)
        _ = try await store.prepareForLaunch()
        try await store.markLaunchSuccessful()

        let second = try sandbox.export(id: "two", key: key)
        _ = try await store.stage(bundleAt: second.rootURL)
        try Data(#"{"updateID":"two"}"#.utf8).write(to: storeRoot.appendingPathComponent("promotion.json"), options: .atomic)
        try Data(#"{"status":"applying","updateID":"two"}"#.utf8).write(to: storeRoot.appendingPathComponent("launch-marker.json"), options: .atomic)
        try FileManager.default.moveItem(
            at: storeRoot.appendingPathComponent("current"),
            to: storeRoot.appendingPathComponent("previous")
        )

        let relaunched = UpdateStore(rootURL: storeRoot, publicKey: key.publicKey)
        guard case let .update(recovered) = try await relaunched.prepareForLaunch() else {
            return XCTFail("expected previous update")
        }
        XCTAssertEqual(recovered.manifest.updateID, "one")
        let badIDs = await relaunched.badUpdates().map(\.updateID)
        XCTAssertEqual(badIDs, ["two"])
    }

    func testRollbackToEmbeddedClearsDownloadedState() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let key = UpdateCrypto.generateKeyPair()
        try sandbox.writeDocument(screen: "paywall")
        let bundle = try sandbox.export(id: "one", key: key)
        let store = UpdateStore(rootURL: sandbox.store(), publicKey: key.publicKey)
        _ = try await store.stage(bundleAt: bundle.rootURL)
        _ = try await store.prepareForLaunch()

        try await store.rollbackToEmbedded()
        let selection = try await store.prepareForLaunch()
        XCTAssertEqual(selection, .embedded)
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ handler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("expected error", file: file, line: line)
    } catch {
        handler(error)
    }
}
