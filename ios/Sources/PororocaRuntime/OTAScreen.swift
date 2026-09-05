import SwiftUI
import os
import PororocaDocument
import PororocaExpr

@MainActor
public struct OTAScreen: View {
    public let source: DocumentSource
    public let state: StateBox
    public let host: ScreenHost
    public let onAction: ActionHandler
    @State private var local: [String: Value]
    @State private var revision: DocumentSource.Revision?

    public init(
        source: DocumentSource,
        state: StateBox,
        localDefaults: [String: Value] = [:],
        host: ScreenHost,
        onAction: @escaping ActionHandler = { _, _ in }
    ) {
        self.source = source
        self.state = state
        self.host = host
        self.onAction = onAction
        _local = State(initialValue: localDefaults)
        _revision = State(initialValue: Self.loadValid(source, host: host))
    }

    public init(
        source: DocumentSource,
        state: StateSnapshot = .init(),
        localDefaults: [String: Value] = [:],
        host: ScreenHost,
        onAction: @escaping ActionHandler = { _, _ in }
    ) {
        self.init(source: source, state: StateBox(state), localDefaults: localDefaults, host: host, onAction: onAction)
    }

    public var body: some View {
        DocumentRenderSignpost.measure { screenBody }
    }

    @ViewBuilder private var screenBody: some View {
        if let document = revision?.document {
            NodeView(
                node: document.root,
                state: state,
                local: $local,
                strings: host.strings(required: document.requires.strings),
                host: host,
                onAction: onAction
            )
            .task(id: revision?.modificationDate) { await watchFile() }
        } else {
            EmptyView()
        }
    }

    private func watchFile() async {
        guard case .file = source, var current = revision else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                if let next = try source.reload(ifChangedFrom: current), let valid = Self.validate(next, host: host) {
                    current = valid
                    revision = valid
                }
            } catch is CancellationError {
                return
            } catch {
                assertionFailure("Pororoca document reload failed: \(error)")
                return
            }
        }
    }

    private static func loadValid(_ source: DocumentSource, host: ScreenHost) -> DocumentSource.Revision? {
        do { return validate(try source.load(), host: host) }
        catch {
            assertionFailure("Pororoca document load failed: \(error)")
            return nil
        }
    }

    private static func validate(_ revision: DocumentSource.Revision, host: ScreenHost) -> DocumentSource.Revision? {
        let errors = Validator.validate(revision.document, against: host.capabilities)
        guard errors.isEmpty else {
            assertionFailure("Invalid Pororoca document: \(errors)")
            return nil
        }
        return revision
    }
}

private enum DocumentRenderSignpost {
    static let log = OSLog(subsystem: "dev.pororoca.runtime", category: "DocumentEvaluation")

    static func measure<Result>(_ operation: () -> Result) -> Result {
        let identifier = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Document body evaluation", signpostID: identifier)
        defer { os_signpost(.end, log: log, name: "Document body evaluation", signpostID: identifier) }
        return operation()
    }
}
