# Pororoca OTA Paywall Spike

This iOS 18.1 spike renders the Trainer Gym AI paywall three ways: hand-written SwiftUI, an embedded Pororoca document, and a JSON file watched in the app's Documents directory. The copied files under `Sources/Copied` identify their read-only origin; StoreKit and application services are replaced by a deterministic debug stub.

Generate and run:

```sh
xcodegen generate
xcodebuild test -scheme PaywallSpike -destination 'platform=iOS Simulator,name=MiseSnag Shipaton iPhone 15 Pro'
```

On first launch, file mode writes `paywall.ios.json` to the app container. To demonstrate a live swap, locate the container with `xcrun simctl get_app_container booted dev.pororoca.PaywallSpike data`, overwrite `Documents/paywall.ios.json` with another valid Pororoca document, and keep the file modification date newer; the screen polls every 250 ms.

For a deterministic Animation Hitches capture, launch the app with `--benchmark native` or `--benchmark document`. Add `--benchmark-toggle` to change row state halfway through the first downward scroll. Benchmark mode hides the controls, uses light appearance, waits two seconds, and scrolls down/up twice with four-second legs.
