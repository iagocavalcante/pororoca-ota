import Foundation
import PororocaLiftAnalysis

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let directory = arguments.first else {
        throw CLIError.usage
    }
    let root = URL(fileURLWithPath: directory).standardizedFileURL
    let summary = try CoverageClassifier.classify(directory: root)
    print(Report.markdown(summary))

    if let flag = arguments.firstIndex(of: "--json"), arguments.indices.contains(flag + 1) {
        let output = URL(fileURLWithPath: arguments[flag + 1])
        try Report.json(summary).write(to: output, options: .atomic)
    }
} catch {
    FileHandle.standardError.write(Data("pororoca-lift-report: \(error)\n".utf8))
    exit(2)
}

private enum CLIError: Error, CustomStringConvertible {
    case usage
    var description: String { "usage: swift run pororoca-lift-report <directory> [--json out.json]" }
}
