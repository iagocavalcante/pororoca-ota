import Foundation
import PororocaExpr
import XCTest

final class EvaluatorSemanticsTests: XCTestCase {
    func testEveryASTFormRoundTrips() throws {
        let formats: [Format] = [
            .number(value: .state("n"), .init(locale: "en_US", minimumFractionDigits: 1, maximumFractionDigits: 2, grouping: true)),
            .currency(value: .state("n"), .init(code: "BRL", locale: "pt_BR")),
            .date(value: .state("timestamp"), .init(locale: "en_US", timeZone: "UTC", dateStyle: .short, timeStyle: DateFormatStyleName.none)),
            .plural(value: .state("n"), .init(locale: "en_US", one: "item", other: "items")),
        ]
        var expressions: [Expr] = [
            .literal(.null), .literal(.bool(true)), .literal(.number(2)), .literal(.string("x")),
            .literal(.array([.number(1), .string("two"), .object(["id": .number(3)])])),
            .state("name"), .local("selection"), .item("title"), .index, .localized("title"),
        ]
        expressions += [
            .eq(.literal(1), .literal(1)), .ne(.literal(1), .literal(2)),
            .lt(.literal(1), .literal(2)), .le(.literal(1), .literal(2)),
            .gt(.literal(2), .literal(1)), .ge(.literal(2), .literal(1)),
        ]
        expressions += [
            .and([.literal(true), .literal(true)]), .or([.literal(false), .literal(true)]),
            .not(.literal(false)), .coalesce([.literal(nil), .literal("fallback")]),
            .concat([.literal("a"), .literal(1)]),
            .case(on: .literal("a"), cases: ["a": .literal(1)], default: .literal(2)),
            .count(.state("items")), .empty(.state("items")),
        ]
        expressions += formats.map(Expr.fmt)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for expression in expressions {
            XCTAssertEqual(try decoder.decode(Expr.self, from: encoder.encode(expression)), expression)
        }
    }

    func testEvaluationIsCappedAtValidatorDepth() {
        let expression = (0..<65).reduce(Expr.literal(true)) { partial, _ in .not(partial) }
        XCTAssertEqual(evaluate(expression, .init()), .null)
    }

    func testIntegralConcatHasNoFractionalSuffix() {
        XCTAssertEqual(evaluate(.concat([.literal(42.0)]), .init()), "42")
    }
}
