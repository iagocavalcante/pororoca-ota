import Foundation
import PororocaLiftAnalysis

enum Report {
    static func markdown(_ summary: CoverageSummary) -> String {
        var lines = [
            "| File | View | Result | Reasons |",
            "|---|---|---:|---|",
        ]
        for entry in summary.entries {
            let reasons = entry.reasons.map { "\($0.code.rawValue):\($0.detail)" }.joined(separator: ", ")
            lines.append("| \(escape(entry.file)) | \(escape(entry.view)) | \(entry.bucket.rawValue) | \(escape(reasons)) |")
        }
        lines += [
            "",
            "Total: \(summary.total)",
            "Clean: \(summary.count(.clean)) (\(format(summary.percentage(.clean)))%)",
            "Small: \(summary.count(.small)) (\(format(summary.percentage(.small)))%)",
            "No: \(summary.count(.no)) (\(format(summary.percentage(.no)))%)",
        ]
        return lines.joined(separator: "\n")
    }

    static func json(_ summary: CoverageSummary) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(summary)
    }

    private static func format(_ value: Double) -> String { String(format: "%.1f", value) }
    private static func escape(_ value: String) -> String { value.replacingOccurrences(of: "|", with: "\\|") }
}
