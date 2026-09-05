import SwiftUI
import UIKit

struct BenchmarkLaunchConfiguration {
    enum Variant: String { case native, document }

    let variant: Variant
    let togglesState: Bool

    static var current: Self? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--benchmark"),
              arguments.indices.contains(flag + 1),
              let variant = Variant(rawValue: arguments[flag + 1])
        else { return nil }
        return Self(variant: variant, togglesState: arguments.contains("--benchmark-toggle"))
    }
}

@MainActor
struct BenchmarkAutomation: UIViewRepresentable {
    let shouldToggleState: Bool
    let toggleState: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        UIApplication.shared.isIdleTimerDisabled = true
        let view = UIView(frame: .zero)
        context.coordinator.schedule(
            from: view,
            shouldToggleState: shouldToggleState,
            toggleState: toggleState
        )
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    @MainActor
    final class Coordinator {
        private var driver: BenchmarkScrollDriver?

        func schedule(from view: UIView, shouldToggleState: Bool, toggleState: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self, weak view] in
                guard let self, let window = view?.window,
                      let scrollView = Self.largestScrollView(in: window)
                else { return }
                let driver = BenchmarkScrollDriver(
                    scrollView: scrollView,
                    shouldToggleState: shouldToggleState,
                    toggleState: toggleState
                )
                self.driver = driver
                driver.start()
            }
        }

        private static func largestScrollView(in view: UIView) -> UIScrollView? {
            let descendants = view.subviews.flatMap { child -> [UIScrollView] in
                var matches = largestScrollViews(in: child)
                if let child = child as? UIScrollView { matches.append(child) }
                return matches
            }
            return descendants.max { $0.contentSize.height < $1.contentSize.height }
        }

        private static func largestScrollViews(in view: UIView) -> [UIScrollView] {
            view.subviews.flatMap { child -> [UIScrollView] in
                var matches = largestScrollViews(in: child)
                if let child = child as? UIScrollView { matches.append(child) }
                return matches
            }
        }
    }
}

@MainActor
private final class BenchmarkScrollDriver: NSObject {
    private weak var scrollView: UIScrollView?
    private let shouldToggleState: Bool
    private let toggleState: () -> Void
    private var displayLink: CADisplayLink?
    private var leg = 0
    private var legStart: CFTimeInterval?
    private var startOffset: CGFloat = 0
    private var endOffset: CGFloat = 0
    private var didToggle = false

    init(scrollView: UIScrollView, shouldToggleState: Bool, toggleState: @escaping () -> Void) {
        self.scrollView = scrollView
        self.shouldToggleState = shouldToggleState
        self.toggleState = toggleState
    }

    func start() {
        beginLeg()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    private func beginLeg() {
        guard let scrollView else { return }
        legStart = nil
        startOffset = scrollView.contentOffset.y
        let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        endOffset = leg.isMultiple(of: 2) ? maximum : -scrollView.adjustedContentInset.top
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let scrollView else { link.invalidate(); return }
        let start = legStart ?? link.timestamp
        legStart = start
        let progress = min(1, (link.timestamp - start) / 4)
        let easedOffset = startOffset + (endOffset - startOffset) * progress
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: easedOffset), animated: false)

        if shouldToggleState, !didToggle, leg == 0, progress >= 0.5 {
            didToggle = true
            toggleState()
        }

        guard progress >= 1 else { return }
        leg += 1
        guard leg < 4 else { link.invalidate(); displayLink = nil; return }
        link.isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak link] in
            guard let self, let link else { return }
            self.beginLeg()
            link.isPaused = false
        }
    }
}
