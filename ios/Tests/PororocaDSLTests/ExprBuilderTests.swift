import PororocaDSL
import XCTest

final class ExprBuilderTests: XCTestCase {
    private struct State: ScreenState {
        static let schema: [String: StateType] = ["phase": .string, "price": .optionalString, "isPro": .bool, "canDismiss": .bool]
    }

    func testStateEqualityBuildsAST() {
        let state = StateRef<State>()
        XCTAssertEqual(state.phase == "purchasing", .eq(.state("phase"), .literal("purchasing")))
    }

    func testInterpolationBuildsConcatAndCoalesce() {
        let state = StateRef<State>()
        let value: Str = "\(t("k")) — \(state.price ?? "…")"
        XCTAssertEqual(value, .expr(.concat([.localized("k"), .literal(" — "), .coalesce([.state("price"), .literal("…")])])))
    }

    func testBooleanOperatorsBuildNestedAST() {
        let state = StateRef<State>()
        XCTAssertEqual(!state.isPro && state.canDismiss, .and([.not(.state("isPro")), .state("canDismiss")]))
        XCTAssertEqual(state.price == nil, .eq(.state("price"), .literal(.null)))
    }
}
