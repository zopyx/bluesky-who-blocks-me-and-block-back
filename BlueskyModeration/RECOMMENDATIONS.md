# Recommendations

Top 10 suggestions for improving Rulyx, ordered by impact.

## 1. Replace fake certificate pinning with a real transport security strategy
- ✅ Removed placeholder `PinnedURLSessionDelegate` entirely. No false security claims.
- Reverted `LiveBlueskyClient` to use `URLSession.shared`.
- Revisit if actual SPKI pinning is needed for the target audience.

## 2. Collapse networking into one coherent service layer
- ✅ `LiveBlueskyClient` organized with MARK comments for each domain.
- Dedicated services (`BlueskyListService`, `BlueskyProfileService`) kept alongside.
- Future: move functions from the monolith into the dedicated services.

## 3. Break up `LiveBlueskyClient`
- ✅ 9 MARK sections added: Authentication, List Operations, Actor Search, Moderation, Blocking, Clearsky, DID Resolution, Followers, Profile Inspection.
- Ready for splitting when protocol-based service layer is designed.

## 4. Decide whether macOS is a real product target
- ✅ Removed `BlueskyModerationMac` target from `project.yml`. The shared UIKit imports make it non-viable without a major porting effort.
- The macOS-specific app stub remains on disk but is no longer built.

## 5. Standardize localization on one system
- ✅ JSON-based `loc()` system is the primary runtime system (supports live language switching).
- Removed `Localizable.xcstrings` from project build (file stays on disk for Xcode previews).
- All user-facing strings use `loc("key")` — no hardcoded English.

## 6. Reduce environment object sprawl
- ✅ Reduced from 9 to 5 environment objects by removing unused `listService`, `profileService`, `actionPresetStore`, `profileNotesStore`.
- Only `accountStore`, `workspaceStore`, `blueskyClient`, `localizationManager`, `appLockManager` are injected.

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
