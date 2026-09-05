import PororocaDocument

/// A host-state schema exposed to a screen document.
public protocol ScreenState: Sendable {
    /// The state keys and their document types.
    static var schema: [String: StateType] { get }
}
