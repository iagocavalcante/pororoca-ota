# Pororoca OTA — Trainer Gym AI lift coverage

Measured with `swift run pororoca-lift-report` against the read-only Trainer Gym AI feature sources on 2026-09-03. The classifier parses Swift syntax without requiring the application or its dependencies to compile. `clean` means no changes were identified, `small` means only state/action annotations or helper inlining, and `no` means at least one unsupported view, modifier, or control-flow construct.

## Results

| Scope | Views | Clean | Small | No |
|---|---:|---:|---:|---:|
| All `Features` | 80 | 3 (3.8%) | 5 (6.2%) | 72 (90.0%) |
| `Features/Paywall` | 1 | 0 (0.0%) | 0 (0.0%) | 1 (100.0%) |

The raw paywall is classified `no` because it contains native lifecycle work (`task`, `onChange`), `if let`, and a parameterized helper. Task 9 kept lifecycle behavior in the native host and made the listed small source changes; that adapted paywall lifts successfully and its generated document root equals the handwritten DSL root.

## Clean and small candidates

| Result | File | View | Small-change reasons |
|---|---|---|---|
| clean | `HealthKitSettings/HealthKitSettingsView.swift` | `SectionCard` | — |
| clean | `Onboarding/Components/OnboardingScaffold.swift` | `OnboardingScaffold` | — |
| clean | `Privacy/PrivacyView.swift` | `SectionCard` | — |
| small | `Habits/IdentityOnboardingView.swift` | `IdentityOnboardingView` | state: `isSaving`, `options`; inline `card` |
| small | `HealthKitSettings/HealthKitSettingsView.swift` | `SectionTitle` | state: `text` |
| small | `Onboarding/ConsentGateView.swift` | `ConsentGateView` | inline `section` |
| small | `Privacy/PrivacyView.swift` | `SectionTitle` | state: `text` |
| small | `WorkoutComplete/ShareCardView.swift` | `ShareCardView` | state: `locale`, `summary`; inline `background`, `heroBlock` |

## Top 10 concrete blockers in the `no` bucket

Counts are the number of affected views containing that exact reason, not raw syntax occurrences.

| Rank | Views | Reason |
|---:|---:|---|
| 1 | 22 | state bridge for `viewModel` |
| 2 | 15 | unsupported modifier `navigationTitle` |
| 3 | 13 | unsupported modifier `task` |
| 4 | 12 | unsupported control flow `if let` |
| 5 | 11 | state bridge for `totalSteps` |
| 6 | 11 | unsupported custom view `OnboardingScaffold` |
| 7 | 10 | state bridge for `currentStep` |
| 8 | 10 | action/state bridge for `onBack` |
| 9 | 10 | action/state bridge for `onContinue` |
| 10 | 9 | state bridge for `items` |

Across all `no` entries, the classifier found 194 state-boundary reasons, 149 unsupported modifiers, 83 unsupported views, 22 parameterized helpers, 14 unsupported control-flow reasons, and 10 action-boundary reasons. The Phase 4 whitelist backlog should prioritize reusable native slots and host boundaries before adding navigation or lifecycle modifiers, because `task`, navigation, analytics, StoreKit, and app routing correctly remain native concerns.

## Reproduce

```sh
cd ios
swift run pororoca-lift-report \
  /Users/iagocavalcante/Workspaces/IagoCavalcante/trainer-gym-ai/apps/mobile/Packages/Modules/Sources/Features \
  --json /tmp/features-coverage.json
swift run pororoca-lift-report \
  /Users/iagocavalcante/Workspaces/IagoCavalcante/trainer-gym-ai/apps/mobile/Packages/Modules/Sources/Features/Paywall \
  --json /tmp/paywall-coverage.json
```
