# Pororoca OTA for SwiftUI

This Swift package validates signed Pororoca bundles, keeps `pending`, `current`, and `previous` updates on disk, recovers from a failed launch, and renders accepted documents as native SwiftUI.

The complete copy-paste integration, launch recovery, and troubleshooting guide is at [pororoca-ota.fly.dev/docs/swiftui](https://pororoca-ota.fly.dev/docs/swiftui).

## 1. Add the package

Pororoca is distributed as source during early access. Check out the repository at a pinned commit, then choose **File → Add Package Dependencies → Add Local…** in Xcode, select the `ios` directory, and link the `Pororoca` product to the app target. The package requires iOS 17 or newer.

Do not track a moving branch in a production app. Upgrade the pinned commit deliberately after running your screen tests.

## 2. Configure the update client

Create an app in the [Pororoca dashboard](https://pororoca-ota.fly.dev/dashboard), then create its app-scoped `runtime` token. Treat that token as a publishable app identifier because mobile credentials are extractable. It can only resolve that app's updates and report untrusted events; the signing private key and expiring `delivery` token belong in CI.

```swift
import Pororoca

let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
let store = UpdateStore(
    rootURL: support.appendingPathComponent("PororocaOTA", isDirectory: true),
    publicKey: publicKey,
    hostCapabilities: ["paywall": HostCapabilities(EmbeddedPaywall.document.requires)]
)

let client = UpdateClient(
    baseURL: URL(string: "https://pororoca-ota.fly.dev")!,
    apiToken: runtimeToken,
    app: "your-app-slug",
    installID: stableInstallID,
    store: store
)
```

`stableInstallID` must survive app launches so staged-rollout membership does not change. Use an app-owned random identifier, not an advertising identifier.

## 3. Select the launch document

Call `prepareForLaunch()` before presenting the updatable screen. A newly downloaded update is promoted on launch; invalid or previously failed updates fall back to `previous`, then to the embedded document.

```swift
let pendingID = await store.pendingUpdateID()
let selection = try await store.prepareForLaunch()

let source: DocumentSource
let updateID: String?
switch selection {
case .embedded:
    source = .embedded(EmbeddedPaywall.document)
    updateID = nil
case let .update(update):
    if let url = update.documentURL(for: "paywall") {
        source = .file(url)
        updateID = update.manifest.updateID
    } else {
        source = .embedded(EmbeddedPaywall.document)
        updateID = nil
    }
}
```

Keep the embedded screen in every app build. It is the trusted final fallback.

## 4. Render with native state and actions

The host owns state, localization, design tokens, navigation, purchases, and every other side effect. The document can only use capabilities declared by the compiled screen.

```swift
let host = ScreenHost(
    capabilities: HostCapabilities(EmbeddedPaywall.document.requires),
    tokens: DictionaryTokenResolver(
        colors: ["background": .black, "text": .white],
        spaces: ["md": 16],
        radii: ["md": 12]
    ),
    localizer: DictionaryLocalizer(["paywall.title": String(localized: "paywall.title")])
)

OTAScreen(
    source: source,
    state: StateSnapshot(["displayPrice": .string(displayPrice)]),
    host: host
) { action, _ in
    if action == "purchase" { purchase() }
}
```

## 5. Mark a new launch healthy

Only mark the update good after the app has reached a known healthy point and the screen rendered. Call this only when the active update was pending at startup.

```swift
if updateID == pendingID, let updateID {
    try await store.markLaunchSuccessful()
    try await client.record(event: "applied", updateID: updateID)
}
```

If the process exits before this marker, the next launch marks that update bad and restores the previous known-good bundle.

## 6. Check in the background

`checkForUpdate()` downloads, verifies, and stages an eligible update. It never replaces the current screen during the running session.

```swift
Task {
    do {
        _ = try await client.checkForUpdate()
    } catch {
        // Keep the current or embedded screen and report through your normal diagnostics.
    }
}
```

For a working host, tokens, actions, and signed-store bootstrap, see [`examples/PaywallSpike`](../examples/PaywallSpike/README.md).

## Supported surface

The Swift runtime supports the schema-v1 nodes, expressions, modifiers, tokens, localized strings, assets, and native slots validated by `PororocaDocument`. Run `swift test` before upgrading the SDK or publishing a new host-capability contract.
