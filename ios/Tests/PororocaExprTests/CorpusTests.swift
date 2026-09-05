import Foundation
import PororocaExpr
import XCTest

final class CorpusTests: XCTestCase {
    private struct CorpusCase: Decodable {
        let name: String
        let env: Environment
        let expr: Expr
        let expected: Value
    }

    func testSharedExpressionCorpus() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let fixture = testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/expr-corpus.json")
        let cases = try JSONDecoder().decode([CorpusCase].self, from: Data(contentsOf: fixture))
        XCTAssertGreaterThanOrEqual(cases.count, 60)
        for testCase in cases {
            XCTAssertEqual(evaluate(testCase.expr, testCase.env), testCase.expected, testCase.name)
        }
    }
}
