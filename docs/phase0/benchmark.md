# Pororoca OTA Phase 0 — 500-row benchmark

## Status

**Pass.** On 2026-09-03, all four `Animation Hitches` captures ran on a physical iPhone 17 (`iPhone18,3`) with iOS 26.6. The document renderer recorded zero hitch time in both the normal-scroll and state-toggle runs, satisfying the fixed limit of 5 ms/s and the 1.5× Native comparison.

The benchmark uses 500 stable-key rows in a lazy column. Each row renders an icon, two text labels, a spacer, and a trailing value with padding, background, and corner radius. `Document body evaluation` signpost intervals are emitted under the `dev.pororoca.runtime` / `DocumentEvaluation` category.

## Results

Hitch time ratio is total hitch duration divided by full trace duration. No warm-up interval or event was excluded.

| Variant | Normal hitch time | Normal hitch count | State-toggle hitch time | State-toggle hitch count |
|---|---:|---:|---:|---:|
| Native | 7.461 ms/s | 5 | 0.000 ms/s | 0 |
| Document | 0.000 ms/s | 0 | 0.000 ms/s | 0 |

The normal Native capture lasted 25.693045 s and contained 191.699250 ms of hitch time. The other capture durations were 23.634460 s for Document normal, 23.583431 s for Native with state toggle, and 23.563690 s for Document with state toggle. The normalized measurements and individual Native hitch events are preserved in [`benchmark-results.json`](benchmark-results.json).

Gate: Document hitch time ratio must be no more than 5 ms/s and no more than 1.5× Native. The acceptance result is **pass** for both scenarios: Document was 0.000 ms/s against Native values of 7.461 ms/s and 0.000 ms/s respectively.

## Reproduction procedure

1. In `examples/PaywallSpike`, run `xcodegen generate`.
2. Connect and unlock an iPhone, confirm Developer Mode, and build/install the `PaywallSpike` scheme. Supply signing locally, for example with `DEVELOPMENT_TEAM=<YOUR_TEAM_ID> CODE_SIGN_STYLE=Automatic`; signing identity is intentionally not committed.
3. Record each deterministic scenario with the `Animation Hitches` template. The app waits two seconds, then scrolls top-to-bottom-to-top twice using four-second legs and 350 ms pauses:

   ```sh
   xcrun xctrace record \
     --template 'Animation Hitches' \
     --device <DEVICE_UDID> \
     --time-limit 22s \
     --output <OUTPUT.trace> \
     --no-prompt \
     --launch -- dev.pororoca.PaywallSpike --benchmark native
   ```

4. Repeat with `--benchmark document`, then repeat both variants with `--benchmark-toggle`. The toggle occurs halfway through the first downward leg and forces state re-evaluation.
5. Export the trace table with `xcrun xctrace export --input <OUTPUT.trace> --xpath '/trace-toc/run[@number="1"]/data/table[@schema="hitches"]'` and compute total hitch duration divided by the run duration from `--toc`.
6. Inspect `Document body evaluation` signposts alongside any hitch events. If Document exceeds either threshold, profile the worst interval and try row caching, per-row expression memoization, or equatable rows in that order; rerun without changing the gate.
