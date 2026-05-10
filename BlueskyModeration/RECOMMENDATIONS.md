# Recommendations

Top 10 suggestions for improving Rulyx, ordered by impact.

## 1. Replace fake certificate pinning with a real transport security strategy
- Remove the current placeholder pinning logic or implement actual SPKI/certificate pinning.
- Avoid code paths that imply stronger protection than the app really provides.
- Add explicit tests around trust evaluation behavior.

## 2. Collapse networking into one coherent service layer
- Choose one abstraction: either `LiveBlueskyClient` as the facade or the dedicated `BlueskyListService` and `BlueskyProfileService`.
- Delete duplicated request logic and keep one source of truth for DTO mapping and API behavior.
- Push views and view models to depend on protocols instead of the concrete mega-client.

## 3. Break up `LiveBlueskyClient`
- The file is too large and mixes authentication, lists, profile lookup, blocking, Clearsky integration, and PLC audit logic.
- Split it into smaller domain-focused services or extensions with clear ownership.
- Keep session restoration and shared request behavior centralized.

## 4. Decide whether macOS is a real product target
- If macOS support is intended, audit shared files for `UIKit` assumptions and build the target in CI.
- If not, remove the target from `project.yml` to avoid a false platform claim.
- Do not leave a permanently red secondary target in the repo.

## 5. Standardize localization on one system
- Pick either Apple string catalogs or the custom JSON-based localization layer.
- Remove hard-coded English strings from views, accessibility labels, and settings copy.
- Review new language files for untranslated English fallback text before shipping.

## 6. Reduce environment object sprawl
- The app root injects many objects globally, which makes feature dependencies less explicit.
- Prefer narrower dependency injection into feature roots and protocol-driven view models.
- This will make previews, tests, and refactors less brittle.

## 7. Persist only the state users expect, and do it consistently
- Finish persistence for workspace preferences like selected tab if that behavior is intentional.
- Audit `UserDefaults`-backed stores for partial or surprising persistence behavior.
- Consider versioning or migration strategy for persisted app state.

## 8. Turn “scaffolded” moderation features into integrated workflows
- Connect action presets and moderation rules to actual moderation execution paths.
- Make it clear in the UI whether a feature is informational, manual, or automated.
- Remove or hide features that are not yet wired into the app’s primary workflows.

## 9. Improve large-batch performance and resilience
- The current batch processor is intentionally conservative but will feel slow on large lists.
- Add bounded concurrency, retry/backoff rules, cancellation semantics, and rate-limit awareness.
- Record richer operation results so failed subsets can be retried precisely.

## 10. Expand end-to-end test coverage around critical flows
- Unit coverage is decent, but UI coverage is minimal.
- Add UI tests for account login, account switching, list loading, list member actions, and profile inspection.
- Add regression tests for session refresh, cache behavior, and localization-sensitive screens.
