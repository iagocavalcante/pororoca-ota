import Foundation

/// Canonical encoding and strict decoding for screen documents.
public enum DocumentCodec {
    public static func decode(_ data: Data) throws -> Document { try JSONDecoder().decode(Document.self, from: data) }
    public static func encode(_ document: Document) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(document); data.append(0x0A); return data
    }
}
