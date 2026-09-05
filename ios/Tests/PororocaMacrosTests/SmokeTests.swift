#if os(macOS)
import XCTest
@testable import PororocaMacros

final class PororocaMacrosSmokeTests: XCTestCase {
    func testPluginLinks() {
        XCTAssertEqual(PororocaPlugin().providingMacros.count, 3)
    }
}
#endif
