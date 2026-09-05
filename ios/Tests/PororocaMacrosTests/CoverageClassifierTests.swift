#if os(macOS)
import XCTest
@testable import PororocaLiftAnalysis

final class CoverageClassifierTests: XCTestCase {
    func testCleanSmallAndNoFixtures() {
        let report = CoverageClassifier.classify(sources: [
            "Clean.swift": """
            import SwiftUI
            struct Clean: View { var body: some View { VStack { Text("Hello") } } }
            """,
            "Small.swift": """
            import SwiftUI
            struct Small: View {
                var enabled = true
                func tapped() {}
                func row(value: Int) -> some View { Text("Row") }
                var body: some View { VStack { if enabled { Button { tapped() } label: { row(value: 1) } } } }
            }
            """,
            "No.swift": """
            import SwiftUI
            struct No: View {
                var value = 1
                var body: some View { switch value { default: CustomView() } }
            }
            """,
        ])

        XCTAssertEqual(report.count(.clean), 1)
        XCTAssertEqual(report.count(.small), 1)
        XCTAssertEqual(report.count(.no), 1)
        XCTAssertEqual(Set(report.entries.first { $0.view == "Small" }!.reasons.map(\.code)), [.notOTAState, .actionNotOTAAction, .parameterizedHelper])
        XCTAssertEqual(Set(report.entries.first { $0.view == "No" }!.reasons.map(\.code)), [.notOTAState, .unsupportedControlFlow, .unsupportedView])
    }
}
#endif
