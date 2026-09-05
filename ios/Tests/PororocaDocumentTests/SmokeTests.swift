import PororocaDocument
import XCTest

final class PororocaDocumentSmokeTests: XCTestCase {
    func testModuleLinks() {
        XCTAssertEqual(PororocaDocument.moduleName, "PororocaDocument")
    }
}
