import Foundation
import PororocaDocument

public enum DocumentSource: Sendable, Equatable {
    case embedded(Document)
    case file(URL)

    public struct Revision: Sendable, Equatable {
        public var document: Document
        public var modificationDate: Date?
        public init(document: Document, modificationDate: Date?) {
            self.document = document
            self.modificationDate = modificationDate
        }
    }

    public func load() throws -> Revision {
        switch self {
        case let .embedded(document):
            return Revision(document: document, modificationDate: nil)
        case let .file(url):
            return Revision(
                document: try DocumentCodec.decode(Data(contentsOf: url)),
                modificationDate: try modificationDate(of: url)
            )
        }
    }

    public func reload(ifChangedFrom revision: Revision) throws -> Revision? {
        guard case let .file(url) = self else { return nil }
        let date = try modificationDate(of: url)
        guard date != revision.modificationDate else { return nil }
        return try load()
    }

    private func modificationDate(of url: URL) throws -> Date? {
        try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
