import Foundation
import PororocaDocument
import XCTest

final class ValidatorTests: XCTestCase {
    private struct Expectation {
        let file: String
        let code: ValidationError.Code
        let path: String
    }

    func testInvalidFixtureCorpus() throws {
        let expectations: [Expectation] = [
            .init(file: "01-unknown-kind.json", code: .unknownKind, path: "/root"),
            .init(file: "02-box-child-count.json", code: .childCount, path: "/root"),
            .init(file: "03-button-child-count.json", code: .childCount, path: "/root"),
            .init(file: "04-scroll-child-count.json", code: .childCount, path: "/root"),
            .init(file: "05-if-condition-type.json", code: .typeMismatch, path: "/root/p/cond"),
            .init(file: "06-foreach-items-type.json", code: .typeMismatch, path: "/root/p/items"),
            .init(file: "07-item-outside-foreach.json", code: .itemOutsideForEach, path: "/root/p/value/expr/item"),
            .init(file: "08-undeclared-state.json", code: .undeclaredState, path: "/root/p/value/expr/state"),
            .init(file: "09-undeclared-color.json", code: .undeclaredToken, path: "/root/mod/foreground/$color"),
            .init(file: "10-undeclared-space.json", code: .undeclaredToken, path: "/root/mod/padding/value/$space"),
            .init(file: "11-undeclared-radius.json", code: .undeclaredToken, path: "/root/mod/cornerRadius/radius/$radius"),
            .init(file: "12-undeclared-font.json", code: .undeclaredToken, path: "/root/mod/font/$font"),
            .init(file: "13-undeclared-string.json", code: .undeclaredString, path: "/root/p/value/$t"),
            .init(file: "14-undeclared-action.json", code: .undeclaredAction, path: "/root/p/action/name"),
            .init(file: "15-undeclared-slot.json", code: .undeclaredSlot, path: "/root/p/name"),
            .init(file: "16-format-version.json", code: .unsupportedFormat, path: "/format"),
            .init(file: "17-negative-frame.json", code: .negativeSize, path: "/root/mod/frame/width"),
            .init(file: "18-opacity-range.json", code: .invalidOpacity, path: "/root/mod/opacity"),
            .init(file: "19-padding-overlap.json", code: .overlappingPadding, path: "/root/mod/padding/1/edges"),
            .init(file: "20-undeclared-asset.json", code: .undeclaredAsset, path: "/root/p/source/$asset"),
            .init(file: "21-invalid-platform.json", code: .invalidValue, path: "/platform"),
            .init(file: "22-unknown-key.json", code: .unknownKey, path: "/root/colour"),
            .init(file: "23-unknown-operator.json", code: .unknownOperator, path: "/root/p/cond"),
            .init(file: "24-disabled-type.json", code: .typeMismatch, path: "/root/mod/disabled"),
            .init(file: "25-hidden-type.json", code: .typeMismatch, path: "/root/mod/hidden"),
            .init(file: "26-undeclared-local.json", code: .undeclaredLocal, path: "/root/p/value/expr/local"),
            .init(file: "27-color-opacity-range.json", code: .invalidOpacity, path: "/root/mod/foreground/opacity"),
        ]
        XCTAssertGreaterThanOrEqual(expectations.count, 25)
        for expectation in expectations {
            let errors = Validator.validate(try fixture("invalid/\(expectation.file)"))
            XCTAssertEqual(errors.count, 1, expectation.file)
            XCTAssertEqual(errors.first?.code, expectation.code, expectation.file)
            XCTAssertEqual(errors.first?.path.pointer, expectation.path, expectation.file)
        }
    }

    func testValidFixturesHaveNoErrors() throws {
        for file in ["documents/minimal.ios.json", "documents/all-kinds.ios.json", "documents/paywall.ios.json"] {
            let data = try fixture(file)
            XCTAssertEqual(Validator.validate(data), [], file)
            if file == "documents/paywall.ios.json" {
                XCTAssertEqual(try DocumentCodec.encode(DocumentCodec.decode(data)), data, "paywall fixture must be canonical")
            }
        }
    }

    func testDepthAndNodeLimits() {
        var deep = Node(.divider)
        for _ in 0..<64 { deep = Node(.box(child: deep)) }
        let deepDocument = document(root: deep)
        XCTAssertEqual(Validator.validate(deepDocument).filter { $0.code == .depthLimit }.count, 1)

        let wide = Node(.vstack(spacing: nil, alignment: nil, children: Array(repeating: Node(.divider), count: 5_001)))
        XCTAssertEqual(Validator.validate(document(root: wide)).filter { $0.code == .nodeLimit }.count, 1)
    }

    func testHostCapabilityDifferenceIsReportedTogether() throws {
        let document = try DocumentCodec.decode(fixture("documents/paywall.ios.json"))
        let host = HostCapabilities(runtime: "0.9.0", state: ["phase": .string])
        let errors = Validator.validate(document, against: host)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first?.code, .capabilityMissing)
        XCTAssertEqual(errors.first?.path.pointer, "/requires")
        XCTAssertTrue(errors.first?.detail.contains("runtime:>=1.0") == true)
        XCTAssertTrue(errors.first?.detail.contains("state:displayPrice") == true)
        XCTAssertTrue(errors.first?.detail.contains("action:purchase") == true)
        XCTAssertTrue(errors.first?.detail.contains("color:background") == true)
    }

    func testMatchingHostCapabilitiesPass() throws {
        let document = try DocumentCodec.decode(fixture("documents/paywall.ios.json"))
        var host = HostCapabilities(document.requires)
        host.runtime = "1.2.0"
        XCTAssertEqual(Validator.validate(document, against: host), [])
    }

    private func fixture(_ path: String) throws -> Data {
        try Data(contentsOf: fixtureURL(path))
    }

    private func fixtureURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/\(path)")
    }

    private func document(root: Node) -> Document {
        Document(screen: "test", platform: .ios, requires: .init(runtime: ">=1.0"), root: root)
    }
}
