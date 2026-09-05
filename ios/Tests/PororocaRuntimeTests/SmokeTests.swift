import PororocaRuntime
import XCTest

final class PororocaRuntimeSmokeTests: XCTestCase {
    func testModuleLinks() {
        XCTAssertEqual(PororocaRuntime.moduleName, "PororocaRuntime")
    }
}
