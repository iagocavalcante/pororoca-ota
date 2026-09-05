import XCTest
import Pororoca
@testable import PaywallSpike

final class BenchmarkScreenTests: XCTestCase {
    func testBenchmarkHasFiveHundredStableRows() {
        XCTAssertEqual(List500Screen.items.count, 500)
        guard case let .array(values) = List500Screen.valueItems else {
            return XCTFail("Expected array state")
        }
        XCTAssertEqual(values.count, 500)
        XCTAssertEqual(Set(values.compactMap(\.numericID)).count, 500)
    }

    func testBenchmarkDocumentIsValidForItsHost() {
        XCTAssertTrue(Validator.validate(List500Screen.document, against: HostCapabilities(List500Screen.document.requires)).isEmpty)
    }
}

private extension Value {
    var numericID: Double? {
        guard case let .object(object) = self, case let .number(id)? = object["id"] else { return nil }
        return id
    }
}
