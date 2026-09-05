import SwiftUI
import Pororoca

@MainActor
struct RootView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case native = "Native"
        case embedded = "Document (embedded)"
        case file = "Document (file)"
        case signed = "Document (signed)"
        case macro = "Document (macro)"
        case listNative = "500 Native"
        case listDocument = "500 Document"
        var id: String { rawValue }
    }

    private let benchmark: BenchmarkLaunchConfiguration?

    @State private var mode: Mode
    @State private var model = PaywallViewModelStub()
    @State private var forceDark: Bool
    @State private var fileURL: URL?
    @State private var signedUpdate: SignedUpdateLaunch?
    @State private var highlightRows = false

    init() {
        let benchmark = BenchmarkLaunchConfiguration.current
        let opensSignedUpdate = ProcessInfo.processInfo.arguments.contains("--signed-update")
        self.benchmark = benchmark
        let initialMode: Mode
        if let benchmark {
            initialMode = benchmark.variant == .document ? .listDocument : .listNative
        } else {
            initialMode = opensSignedUpdate ? .signed : .native
        }
        _mode = State(initialValue: initialMode)
        _forceDark = State(initialValue: benchmark == nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            if benchmark == nil { controls }
            Group {
                switch mode {
                case .native: PaywallView(viewModel: model)
                case .embedded: PaywallDocumentView(source: .embedded(PaywallScreen.document), viewModel: model)
                case .file:
                    if let fileURL { PaywallDocumentView(source: .file(fileURL), viewModel: model) }
                    else { ContentUnavailableView("File unavailable", systemImage: "doc.badge.ellipsis") }
                case .signed:
                    if let url = signedUpdate?.documentURL {
                        PaywallDocumentView(source: .file(url), viewModel: model)
                    } else {
                        ContentUnavailableView(
                            "No signed update",
                            systemImage: "checkmark.shield",
                            description: SwiftUI.Text(signedUpdate?.status ?? "Checking the local update store…")
                        )
                    }
                case .macro: PaywallViewUpdatable(viewModel: model)
                case .listNative: List500Native(highlight: highlightRows)
                case .listDocument: List500Document(highlight: highlightRows)
                }
            }
        }
        .preferredColorScheme(forceDark ? .dark : .light)
        .task {
            fileURL = try? PaywallDocumentFile.bootstrap()
            let launch = await SignedUpdateBootstrap.prepare()
            signedUpdate = launch
            guard launch.updateID != nil, let store = launch.store else { return }
            try? await Task.sleep(for: .seconds(10))
            try? await store.markLaunchSuccessful()
        }
        .overlay {
            if let benchmark {
                BenchmarkAutomation(shouldToggleState: benchmark.togglesState) {
                    highlightRows.toggle()
                }
                .frame(width: 0, height: 0)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Renderer", selection: $mode) {
                ForEach(Mode.allCases) { SwiftUI.Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Picker("Phase", selection: $model.phase) {
                    ForEach(PaywallPhase.allCases) { SwiftUI.Text($0.rawValue).tag($0) }
                }
                TextField("Price", text: $model.displayPrice).textFieldStyle(.roundedBorder)
                Toggle("Dismiss", isOn: $model.canDismiss)
                Toggle("Dark", isOn: $forceDark)
                Toggle("Rows", isOn: $highlightRows)
            }
            .font(.caption)
        }
        .padding(8)
        .background(.ultraThinMaterial)
    }
}
