import Pororoca
import XCTest
@testable import PaywallSpike

@MainActor
final class PaywallLiftTests: XCTestCase {
    func testMacroDocumentValidatesAndExposesTheMarkedContract() {
        let document = PaywallViewUpdatable.__pororocaDocument
        XCTAssertTrue(Validator.validate(document, against: HostCapabilities(document.requires)).isEmpty)
        XCTAssertEqual(document.screen, "paywall")
        XCTAssertEqual(document.requires.state, [
            "phase": .string,
            "failureReason": .optionalString,
            "displayPrice": .optionalString,
            "canDismiss": .bool,
        ])
        XCTAssertTrue(Set(["purchase", "restore", "redeemCode", "dismiss"]).isSubset(of: Set(document.requires.actions)))
        XCTAssertEqual(document.root, PaywallScreen.document.root)
    }
}
