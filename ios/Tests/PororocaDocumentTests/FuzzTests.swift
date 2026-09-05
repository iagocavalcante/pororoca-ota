import Foundation
import PororocaDocument
import XCTest

final class FuzzTests: XCTestCase {
    func testTwoThousandRandomMutationsNeverCrashOrExceedBudget() throws {
        let source = try fixture("documents/all-kinds.ios.json")
        let base = try XCTUnwrap(try JSONSerialization.jsonObject(with: source) as? [String: Any])
        var random = LCRandom(seed: 0x5550_4C49_4E4B)

        for iteration in 0..<2_000 {
            var value = base
            switch iteration % 4 {
            case 0:
                let keys = value.keys.sorted()
                if let key = keys.randomElement(using: &random) { value.removeValue(forKey: key) }
            case 1:
                let scalars: [Any] = [NSNull(), true, false, random.nextInt(upperBound: 10), "mutated"]
                let keys = ["format", "screen", "platform", "requires", "root"]
                value[keys[random.nextInt(upperBound: keys.count)]] = scalars[random.nextInt(upperBound: scalars.count)]
            case 2:
                if var root = value["root"] as? [String: Any], var children = root["c"] as? [Any], let first = children.first {
                    children.append(first); root["c"] = children; value["root"] = root
                }
            default:
                if let root = value["root"] { value["root"] = ["t": "box", "c": [root]] }
            }

            let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
            let start = ContinuousClock.now
            _ = Validator.validate(data)
            let elapsed = start.duration(to: .now)
            XCTAssertLessThan(elapsed, .milliseconds(50), "mutation \(iteration) exceeded 50 ms")
        }
    }

    private func fixture(_ path: String) throws -> Data {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures/\(path)")
        return try Data(contentsOf: file)
    }
}

private struct LCRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 { state = 6_364_136_223_846_793_005 &* state &+ 1; return state }
    mutating func nextInt(upperBound: Int) -> Int { Int(next() % UInt64(upperBound)) }
}
