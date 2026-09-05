import Foundation
import XCTest
import PororocaDocument
@testable import PororocaRuntime

final class DocumentSourceTests: XCTestCase {
    func testFileReloadsOnlyAfterModificationDateChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("screen.ios.json")
        let source = DocumentSource.file(url)
        let firstDocument = document(screen: "first")
        try DocumentCodec.encode(firstDocument).write(to: url)
        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: firstDate], ofItemAtPath: url.path)

        let first = try source.load()
        XCTAssertEqual(first.document, firstDocument)
        XCTAssertNil(try source.reload(ifChangedFrom: first))

        let secondDocument = document(screen: "second")
        try DocumentCodec.encode(secondDocument).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: firstDate.addingTimeInterval(5)], ofItemAtPath: url.path)

        let second = try XCTUnwrap(source.reload(ifChangedFrom: first))
        XCTAssertEqual(second.document, secondDocument)
    }

    func testEmbeddedDocumentNeverReloads() throws {
        let source = DocumentSource.embedded(document(screen: "embedded"))
        let revision = try source.load()
        XCTAssertNil(try source.reload(ifChangedFrom: revision))
    }

    private func document(screen: String) -> Document {
        Document(screen: screen, platform: .ios, requires: .init(runtime: "1"), root: Node(.text(value: .literal(screen))))
    }
}
