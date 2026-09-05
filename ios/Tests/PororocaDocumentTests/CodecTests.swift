import Foundation
import PororocaDocument
import PororocaExpr
import XCTest

final class CodecTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: fixtureURL(name))
    }

    private func fixtureURL(_ name: String) -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/documents/\(name)")
    }

    func testFixturesRoundTripAndUseCanonicalEncoding() throws {
        for name in ["minimal.ios.json", "all-kinds.ios.json"] {
            let data = try fixture(name)
            let first = try DocumentCodec.decode(data)
            let encoded = try DocumentCodec.encode(first)
            XCTAssertEqual(try DocumentCodec.decode(encoded), first, name)
            XCTAssertEqual(encoded, try DocumentCodec.encode(first), name)
            XCTAssertEqual(encoded, data, "fixture must be canonical: \(name)")
        }
    }

    func testUnknownKeyReportsFullPath() throws {
        XCTAssertThrowsError(try DocumentCodec.decode(fixture("unknown-key.ios.json"))) { error in
            guard let strict = error as? StrictDecodingError else { return XCTFail("unexpected error: \(error)") }
            XCTAssertEqual(strict.path.pointer, "/root/mod/colour")
            XCTAssertEqual(strict.key, "colour")
        }
    }

    func testNodeStructuralErrors() throws {
        try assertDocumentError(root: #"{"t":"box","c":[{"t":"divider"},{"t":"divider"}]}"#, code: .childCount)
        try assertDocumentError(root: #"{"t":"button","p":{"action":{"name":"dismiss"}},"c":[]}"#, code: .childCount)
        try assertDocumentError(root: #"{"t":"if","p":{"cond":true,"then":{"t":"divider"}},"c":[]}"#, code: .unexpectedChildren)
        try assertDocumentError(root: #"{"t":"grid"}"#, code: .unknownKind)
    }

    func testMalformedValuesAndExpressions() throws {
        XCTAssertThrowsError(try decodeRoot(##"{"t":"shape","p":{"kind":"rect","fill":{"hex":"#12"}}}"##)) { error in
            XCTAssertEqual((error as? DocumentCodecError)?.code, .invalidValue)
        }
        XCTAssertThrowsError(try decodeRoot(#"{"t":"if","p":{"cond":{"plus":[1,2]},"then":{"t":"divider"}}}"#)) { error in
            XCTAssertEqual((error as? ExprCodecError)?.code, .unknownOperator)
        }
        XCTAssertThrowsError(try decodeRoot(#"{"t":"if","p":{"cond":{"==":[1]},"then":{"t":"divider"}}}"#)) { error in
            XCTAssertEqual((error as? ExprCodecError)?.code, .malformed)
        }
    }

    func testRepresentativeValueForms() throws {
        XCTAssertEqual(try decode(ColorValue.self, #"{"$color":"primary","opacity":0.5}"#), .token(name: "primary", opacity: 0.5))
        XCTAssertEqual(try decode(ColorValue.self, ##"{"hex":"#AABBCCDD"}"##), .hex(HexColor("#AABBCCDD")!))
        XCTAssertEqual(try decode(Dim.self, "12"), .points(12))
        XCTAssertEqual(try decode(Dim.self, #"{"$space":"md"}"#), .token("md"))
        XCTAssertEqual(try decode(Radius.self, #"{"$radius":"lg"}"#), .token("lg"))
        XCTAssertEqual(try decode(FontValue.self, #"{"$font":"body"}"#), .token("body"))
        XCTAssertEqual(try decode(FontValue.self, #"{"system":{"size":17,"weight":"bold","design":"rounded"}}"#), .system(.init(size: 17, weight: .bold, design: .rounded)))
        XCTAssertEqual(try decode(Str.self, #"{"$t":"cta"}"#), .localized("cta"))
        XCTAssertEqual(try decode(Str.self, #"{"expr":{"state":"title"}}"#), .expr(.state("title")))
        XCTAssertEqual(try decode(FrameDimension.self, #""infinity""#), .infinity)
        XCTAssertEqual(try decode(ImageSource.self, #"{"$bundled":"hero"}"#), .bundled("hero"))
        XCTAssertEqual(try decode(ImageSource.self, #"{"$asset":"sha256:abc"}"#), .asset("sha256:abc"))
        XCTAssertEqual(try decode(SlotProp.self, "true"), .bool(true))
        XCTAssertEqual(try decode(SlotProp.self, "3"), .number(3))
    }

    func testPaddingSingleAndArray() throws {
        let one = try decode(ModifierProps.self, #"{"padding":{"edges":"all","value":8}}"#)
        let two = try decode(ModifierProps.self, #"{"padding":[{"edges":"horizontal","value":8},{"edges":"bottom","value":{"$space":"sm"}}]}"#)
        XCTAssertEqual(one.padding, [.init(edges: .all, value: .points(8))])
        XCTAssertEqual(two.padding.count, 2)
    }

    func testAbsentEmptyNormalization() throws {
        let root = try decodeRoot(#"{"t":"text","p":{"value":"Hi"},"mod":{}}"#)
        XCTAssertNil(root.mod)
        let document = try DocumentCodec.decode(Data(#"{"format":1,"screen":"x","platform":"ios","requires":{"runtime":">=1.0"},"root":{"t":"text","p":{"value":"Hi"}}}"#.utf8))
        XCTAssertTrue(document.requires.actions.isEmpty)
        XCTAssertFalse(String(decoding: try DocumentCodec.encode(document), as: UTF8.self).contains(#""local""#))
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T { try JSONDecoder().decode(type, from: Data(json.utf8)) }
    private func decodeRoot(_ root: String) throws -> Node {
        try DocumentCodec.decode(Data(#"{"format":1,"screen":"inline","platform":"ios","requires":{"runtime":">=1.0"},"root":\#(root)}"#.utf8)).root
    }
    private func assertDocumentError(root: String, code: DocumentCodecError.Code) throws {
        XCTAssertThrowsError(try decodeRoot(root)) { error in
            guard let documentError = error as? DocumentCodecError else { return XCTFail("unexpected error: \(error)") }
            XCTAssertEqual(documentError.code, code); XCTAssertEqual(documentError.path.pointer, "/root")
        }
    }
}
