# Pororoca OTA — Phase 0 Report

## Gate decision

| Gate | Result | Evidence |
|---|---|---|
| Fidelity: paywall pixel-close on iPhone and iPad, light and dark | **Pass** | The native/document snapshot suite passed all four device/appearance combinations at 0.99 pixel precision and 0.98 perceptual precision. Images are in [`docs/phase0/fidelity/`](phase0/fidelity/). |
| Preview workflow: `#Preview` renders the document through the runtime in Xcode | **Pass** | `PaywallDocumentView.swift` contains a live `#Preview`; Xcode Canvas rendered the embedded document on an iPhone 17 simulator. See [`preview-document-paywall.jpg`](phase0/preview-document-paywall.jpg). |
| Benchmark: 500-row document list ≤ 5 ms/s hitch time and ≤ 1.5× native | **Pass** | Four physical-device Animation Hitches captures passed. Document measured 0.000 ms/s with 0 hitches in both normal and state-toggle runs; Native measured 7.461 ms/s (5 hitches) and 0.000 ms/s (0 hitches). See [`benchmark.md`](phase0/benchmark.md) and [`benchmark-results.json`](phase0/benchmark-results.json). |
| Macro lifts the real paywall with the listed small changes | **Pass** | The adapted paywall's generated root equals the handwritten DSL root, validates against the same host contract, and passes all six macro fidelity cases. |
| Coverage over Trainer Gym AI `Features` | **3.8% clean / 6.2% small / 90.0% no** | 80 views measured. The largest concrete blockers are the `viewModel` state bridge (22 views), `navigationTitle` (15), `task` (13), `if let` (12), and app-specific state/action boundaries. See [`coverage.md`](phase0/coverage.md). |
| Schema changes forced by the paywall | **None** | The existing schema represents the adapted paywall without additions. |
| Blockers and hacks avoided | **No remaining gate blockers; no workarounds** | The implementation did not fabricate simulator performance, download code, add an interpreter, approximate unsupported lifecycle behavior, or erase renderer structure with `AnyView`; unsupported behavior stays native or produces diagnostics. Physical measurements include every recorded hitch with no warm-up exclusion. |

## Recommendation

Continue to Phase 1 with the DSL as the primary authoring path and position the macro as an experimental upgrade, not the headline. Fidelity, Xcode preview, the physical-device renderer benchmark, and the adapted-paywall macro all pass. However, 10.0% clean-plus-small coverage remains below a credible general-purpose SwiftUI lifting claim, so server and update-client work should keep the DSL-first scope and treat broader source lifting as later research.

## Schema changes forced by the paywall

None. The adapted Trainer Gym AI paywall is represented by the Phase 0 node, expression, modifier, token, localization, state, and action contracts without changing the document schema.

The standalone spike substitutes deterministic state for StoreKit and renders legal destinations as styled text because external navigation belongs to the host action boundary. Those are host-integration adaptations, not schema changes.

## Macro feasibility

`@Updatable` lifts the adapted SwiftUI paywall into the shared DSL, emits its document/state/action/host members, and renders it through `OTAScreen`. `@OTAState` and `@OTAAction` make the host boundary explicit. The emitted root is structurally equal to the handwritten DSL root; all six native/document fidelity cases also pass for the macro-generated document at 0.99 pixel precision and 0.98 perceptual precision.

The only fidelity-specific implementation detail was preserving `Image(systemName:).font(.system(...))` as intrinsic icon size and weight. Treating that font as a generic modifier changed SF Symbol geometry enough to fail the existing threshold.
