# Pororoca OTA for Jetpack Compose

The `sdk` module verifies Ed25519 signatures and SHA-256 file hashes before strict decoding, then renders accepted documents as native Compose UI. The `app` module is a runnable integration example.

## 1. Add the SDK

Pororoca is distributed as source during early access. Pin the supplied repository checkout and open the `android` workspace to run the sample. For an existing app, include the `sdk` module from that pinned checkout and add `implementation(project(":pororocaSdk"))`. The host build must make the Android library, Kotlin Compose, and Kotlin serialization plugins available; the included workspace pins the known-good versions. The SDK requires Android API 26 or newer.

The complete copy-paste integration, offline storage, and testing guide is at [pororoca-ota.fly.dev/docs/compose](https://pororoca-ota.fly.dev/docs/compose).

Run its verification suite before integrating a new revision:

```sh
./gradlew :sdk:testDebugUnitTest :app:assembleDebug
```

## 2. Configure a runtime client

Create an app in the [Pororoca dashboard](https://pororoca-ota.fly.dev/dashboard), then create a `runtime` token. Bundle only the public Ed25519 key and runtime token in the app. Keep the signing private key and `delivery` token in CI.

```kotlin
val client = PororocaClient(
  serverUrl = "https://pororoca-ota.fly.dev",
  apiToken = BuildConfig.POROROCA_RUNTIME_TOKEN,
  app = "your-app-slug",
  installId = stableInstallId,
  publicKey = publicKeyBytes,
)
```

`stableInstallId` must persist across launches so the device stays in the same staged-rollout cohort. Use an app-owned random ID, not an advertising ID.

## 3. Retain the last verified document

Run network work from a coroutine, never on the main thread. The client returns both decoded documents and their verified source bytes so the host can persist an offline copy.

```kotlin
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption

val update = runCatching { client.checkForUpdate() }.getOrNull()
val currentFile = File(context.filesDir, "pororoca/paywall.json")

update?.documentBytes?.get("paywall")?.let { bytes ->
  currentFile.parentFile?.mkdirs()
  val pending = File(currentFile.parentFile, "paywall.pending")
  pending.writeBytes(bytes)
  Files.move(
    pending.toPath(),
    currentFile.toPath(),
    StandardCopyOption.ATOMIC_MOVE,
    StandardCopyOption.REPLACE_EXISTING,
  )
}

val document =
  update?.documents?.get("paywall")
    ?: runCatching { PororocaDocument.decode(currentFile.readBytes()) }.getOrNull()
    ?: PororocaDocument.decode(EMBEDDED_PAYWALL.encodeToByteArray())
```

Keep an embedded document in every app build. The host-owned file is the current Android early-access storage contract; managed `current`/`previous` crash recovery is not yet included as it is on iOS.

## 4. Render and handle native actions

```kotlin
PororocaScreen(
  document = document,
  host = PororocaHost(
    strings = mapOf("paywall.title" to stringResource(R.string.paywall_title)),
    onAction = { action ->
      if (action == "purchase") launchBillingFlow()
    },
  ),
)
```

The document controls presentation only. Billing, navigation, analytics, and every side effect remain compiled Kotlin code owned by the host app.

After the verified document renders, report adoption:

```kotlin
update?.let { client.record(event = "applied", updateId = it.id) }
```

## Supported surface

The current native subset is `vstack`, `hstack`, `zstack`, `box`, `spacer`, `scroll`, `lazycolumn`, `text`, `divider`, `progress`, and `button`. Text may be literal or resolved through the host string table; buttons emit a named action. Full Swift expression/modifier parity and a managed Android rollback store remain post-MVP work.
