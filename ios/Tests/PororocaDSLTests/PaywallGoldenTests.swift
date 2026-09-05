import Foundation
import PororocaDSL
import XCTest

final class PaywallGoldenTests: XCTestCase {
    private enum TestAction: String, ScreenAction { case noop }

    func testPaywallDSLMatchesCanonicalGolden() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/documents/paywall.ios.json")
        XCTAssertEqual(try DocumentCodec.encode(PaywallScreen.document), try Data(contentsOf: file))
        XCTAssertEqual(Validator.validate(PaywallScreen.document), [])
    }

    func testScreenCollectsSchemaActionsTokensAndStrings() {
        let requires = PaywallScreen.document.requires
        XCTAssertEqual(requires.state, PaywallScreen.State.schema)
        XCTAssertEqual(requires.actions, PaywallScreen.Action.allCases.map(\.rawValue))
        XCTAssertEqual(Set(requires.tokens.color), ["background", "text"])
        XCTAssertEqual(Set(requires.tokens.space), ["lg", "xl"])
        XCTAssertEqual(requires.tokens.font, ["title"])
        XCTAssertEqual(Set(requires.strings), ["appName", "slogan", "paywallUnlock"])
    }

    func testScreenCollectsSlotsAndAssets() {
        let document = Screen("resources", state: PaywallScreen.State.self, actions: TestAction.self) { _, _ in
            VStack {
                Slot("banner")
                Image(asset: "sha256:abc")
            }
        }
        XCTAssertEqual(document.requires.slots, ["banner"])
        XCTAssertEqual(document.requires.assets, ["sha256:abc"])
    }
}
