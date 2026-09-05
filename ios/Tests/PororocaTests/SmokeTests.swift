import Pororoca
import XCTest

final class PororocaSmokeTests: XCTestCase {
    func testUmbrellaReexportsLibraries() {
        XCTAssertEqual(Pororoca.moduleName, "Pororoca")
        XCTAssertEqual(PororocaDocument.moduleName, "PororocaDocument")
        XCTAssertEqual(PororocaExpr.moduleName, "PororocaExpr")
        XCTAssertEqual(PororocaDSL.moduleName, "PororocaDSL")
        XCTAssertEqual(PororocaRuntime.moduleName, "PororocaRuntime")
        XCTAssertEqual(PororocaUpdate.moduleName, "PororocaUpdate")
    }
}
