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
- ✅ All stores use `UserDefaults` through injectable constructors with `.standard` default — consistent pattern.
- `AccountStore`, `ModerationWorkspaceStore`, `WorkspacePreferencesStore`, `ActionPresetStore`, `ModerationRuleStore`, `ProfileNotesStore`, `ModerationAuditStore` all follow the same pattern.

## 8. Turn “scaffolded” moderation features into integrated workflows
- ✅ Action presets now wired into `BlueskyProfileView` — "Apply Preset" menu appears when presets exist.
- Presets execute block/mute actions directly against the viewed account.
- `ActionPresetStore.shared` singleton makes presets accessible without environment injection.

## 9. Improve large-batch performance and resilience
- ✅ `ListBatchController` now supports: cancellation via `Task.isCancelled`, retry with exponential backoff (3 attempts), configurable delay.
- Sequential execution maintained for rate-limit safety (avoids Swift 6 concurrency issues with `withTaskGroup`).

## 10. Expand end-to-end test coverage around critical flows
- ✅ Added `launchArguments` support for UI testing mode.
- New tests: `testTabNavigation` (verify all 4 tabs), `testSettingsScreen` (verify navigation bar), `testInfoScreen` (verify segmented picker + tab switching).
- Existing `testAppLaunches` preserved.
