/// An action enum exposed to a screen document.
public protocol ScreenAction: RawRepresentable, CaseIterable, Sendable where RawValue == String {}

public extension ScreenAction {
    /// All action names in declaration order.
    static var names: [String] { allCases.map(\.rawValue) }
}
