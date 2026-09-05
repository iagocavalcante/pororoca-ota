# Pororoca OTA

Open-source tooling for signed over-the-air presentation updates in native SwiftUI and Jetpack Compose apps.

Pororoca documents control layout and presentation. Compiled native code keeps ownership of state, purchases, authentication, navigation, data access, analytics, and every side effect. Each app ships an embedded fallback and verifies downloaded bundles with Ed25519 before rendering them.

## Open-source platform

- [`ios/`](ios/README.md) — Swift DSL, schema, validator, expression engine, SwiftUI renderer, signed bundle publisher, and crash-safe update store.
- [`android/`](android/README.md) — strict Android decoder, signature and hash verification, Jetpack Compose renderer, and sample app.
- [`mcp/`](mcp/README.md) — local MCP server for inspecting channels, publishing signed bundles, changing rollout, and rollback.
- [`examples/`](examples/) — runnable native integration examples.
- [`docs/`](docs/) — benchmarks, threat model, signed-update contract, and implementation reports.

The hosted Pororoca control plane—accounts, billing, delivery storage, telemetry, and operations—is a commercial service and is not part of this repository. This is the same product boundary used by platforms such as Expo: the native framework and developer tools are open, while managed cloud delivery funds their development.

## Start here

- [Complete setup documentation](https://pororoca-ota.fly.dev/docs)
- [SwiftUI integration](https://pororoca-ota.fly.dev/docs/swiftui)
- [Jetpack Compose integration](https://pororoca-ota.fly.dev/docs/compose)
- [Publisher and CI](https://pororoca-ota.fly.dev/docs/publisher)
- [MCP and coding agents](https://pororoca-ota.fly.dev/docs/mcp)
- [Machine-readable agent runbook](https://pororoca-ota.fly.dev/llms-full.txt)

## Build and test

Swift:

```sh
cd ios
swift test
```

Android:

```sh
cd android
./gradlew :sdk:testDebugUnitTest :app:assembleDebug
```

MCP:

```sh
cd mcp
npm ci
npm run check
npm run build
```

## Security model

- Mobile apps receive only a runtime token and the Ed25519 public key.
- CI and MCP receive a delivery token; CI alone receives the private signing key.
- Bundles are signed, content-addressed, strictly decoded, and checked against compiled host capabilities.
- Documents emit named actions; they cannot name or download arbitrary executable code.
- Production rollouts should begin at 10%, with an embedded fallback available at all times.

Please report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Status

Pororoca is early access. The SwiftUI runtime has the broader schema-v1 surface and managed failed-launch recovery. Android currently has a smaller renderer surface and host-managed offline retention. These limits are documented rather than hidden.

## License

MIT. See [LICENSE](LICENSE).
