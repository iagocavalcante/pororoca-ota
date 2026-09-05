@MainActor
public protocol Localizer {
    func string(for key: String) -> String
}

public struct DictionaryLocalizer: Localizer {
    public var strings: [String: String]

    public init(_ strings: [String: String] = [:]) {
        self.strings = strings
    }

    public func string(for key: String) -> String { strings[key] ?? key }
}

/// Adapts an application's existing localization function to the runtime.
public struct ClosureLocalizer: Localizer {
    private let resolve: @MainActor (String) -> String

    public init(_ resolve: @escaping @MainActor (String) -> String) {
        self.resolve = resolve
    }

    public func string(for key: String) -> String { resolve(key) }
}
