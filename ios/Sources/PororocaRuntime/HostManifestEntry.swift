import PororocaDocument

/// Static metadata emitted by `@Updatable` for host registration and tooling.
public struct HostManifestEntry: Sendable, Equatable {
    public var screen: String
    public var requires: Requires

    public init(screen: String, requires: Requires) {
        self.screen = screen
        self.requires = requires
    }
}
