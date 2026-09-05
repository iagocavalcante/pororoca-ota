# Contributing to Pororoca OTA

Thanks for helping make safe native UI delivery better.

## Before opening a change

1. Open an issue for behavioral or schema changes so iOS and Android compatibility can be discussed first.
2. Keep documents presentation-only. Native code must continue to own side effects and sensitive data.
3. Preserve strict decoding, signature verification, capability checks, and embedded fallback behavior.
4. Add the smallest test that proves the change and run the affected platform checks.

## Checks

```sh
(cd ios && swift test)
(cd android && ./gradlew :sdk:testDebugUnitTest :app:assembleDebug)
(cd mcp && npm ci && npm run check)
```

Use focused commits and explain compatibility or security impact in the pull request. By contributing, you agree that your contribution is licensed under the repository's MIT License.
