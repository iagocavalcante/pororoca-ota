import PororocaExpr
import XCTest

final class PororocaExprSmokeTests: XCTestCase {
    func testModuleLinks() {
        XCTAssertEqual(PororocaExpr.moduleName, "PororocaExpr")
    }
}
