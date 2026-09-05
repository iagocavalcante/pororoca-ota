import PororocaDSL
import XCTest

final class PororocaDSLSmokeTests: XCTestCase {
    func testModuleLinks() {
        XCTAssertEqual(PororocaDSL.moduleName, "PororocaDSL")
    }
}
