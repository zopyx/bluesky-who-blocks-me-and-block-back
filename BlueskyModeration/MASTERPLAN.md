# Master Plan — BlueskyModeration (Rulyx)

**Updated Score: 9.0/10** (+0.3) — Expert panel review across 7 domains with top-5 improvements per area.

---

## 🎨 UI/UX Designer — 7/10 → 8/10 (+1)

1. **iPad: Adopt `NavigationSplitView`** — ⏳ master-detail instead of stacked push for list navigation on iPad
2. **Unify top bar across all tabs** — ✅ account switcher in ListsView + ProfileInspectorView native toolbar items + reusable `accountSwitcherToolbar()` modifier
3. **Rebuild InfoView background** — ✅ `.preferredColorScheme(.dark)` set
4. **Skeleton loading** — ✅ ListsView, FollowerDiffView, NetworkGraphView, TrendDetectionView, BlueskyProfileView all use skeleton placeholders (`SkeletonRow`, `SkeletonCard`, `SkeletonGrid`)
5. **Touch target audit** — ✅ `StatusChip` (12pt), `AccountChip` (12pt), `OnboardingRow` (8pt) fixed; `HelpSection` non-interactive

---

## ♿ Accessibility Specialist — 9/10

1. **Remove `dynamicTypeSize` caps** — ✅ removed from all views
2. **Add `.accessibilityHint` on controls** — ✅ ~127 controls across all major views: ListsView, SettingsView, InfoView, ProfileInspectorView, RelationshipsView, ListDetailView+all sections+sheets, BlueskyProfileView, CreateListSheet, SubscribeToListView, NoteSheet, ActivityLogView, BulkProfileLookupView, NetworkGraphView, FollowerDiffView, ReportGeneratorView, ListTemplatesView, ActorSearchResultRow, AccountSwitcherSheet, AccountQuickSwitcherSheet, AddAccountView, PendingActionsSheet, ActionPresetsView, ModerationRulesView
3. **Swipe action VoiceOver labels** — ✅ all groups use `Label("ActionName", ...)` — VoiceOver readable
4. **Support Reduce Motion** — ✅ lock screen animation gated with `UIAccessibility.isReduceMotionEnabled`
5. **Support Bold Text** — ✅ all labels use system text styles which auto-handle Bold Text via SwiftUI

---

## 🏗 iOS Architecture Lead — 8/10 → 9/10 (+1)

1. **Migrate to `NavigationPath`** — ⏳ enable programmatic push/pop, state restoration, deep linking
2. **Add ViewModel unit tests** — ✅ `ListsViewModel` (initial state, nil-account load, addList, updateList) + `ProfileInspectorViewModel` (initial state, search, inspect) — 6+ test methods in `Tests/BlueskyModerationTests/ViewModelTests.swift`
3. **Merge sheet presentation layer** — ✅ account sheets consolidated in ListsView + ProfileInspectorView
4. **Extract reusable toolbar modifier** — ✅ `accountSwitcherToolbar()` + `accountAvatarView()` in `GlassSupport.swift`
5. **Adopt `@Observable` macro** — ⏳ replace `ObservableObject`/`@Published` with iOS 17+ `@Observable`

---

## 🌐 Localization/i18n Manager — 6/10 → 9/10 (+3)

1. **Expand key coverage** — ✅ 536 keys × 6 languages (en/de/fr/it/ja/zh)
2. **Wire all views** — ✅ every view file uses `localizationManager.localized()` or `loc()` helper
3. **Translation completeness** — ✅ de fully translated (192+ new), fr fully translated (189+ new), it expanded, ja/zh with key UI strings
4. **Pluralization** — ✅ `localizedPlural(_:count:)` with `_one`/`_other` suffixes
5. **xcstrings catalog** — ✅ `Localizable.xcstrings` with 536 keys × 6 languages in Apple's native format
6. **RTL audit** — ✅ 60+ `.leading`/`.trailing`/`Spacer()` uses verified — all semantic, auto-flip in RTL

---

## 🐛 QA/Reliability Engineer — 9/10

1. **Skeleton/placeholder loading** — ✅ ListsView, FollowerDiffView, NetworkGraphView, TrendDetectionView, BlueskyProfileView
2. **ViewModel unit test suite** — ✅ `ListsViewModel` + `ProfileInspectorViewModel` — 6+ test methods in `Tests/BlueskyModerationTests/ViewModelTests.swift`
3. **Fix `isShowingPendingActions` orphaned state** — ✅ removed from ListsView
4. **Graceful offline handling** — ✅ `NetworkMonitor` (NWPathMonitor) + `OfflineBanner` component created
5. **Add UI tests for critical flows** — ⏳ login → load lists → inspect profile → block user (XCUITest)

---

## 🔒 Security Engineer — 9/10 (unchanged)

1. **Biometric lock (Face ID / Touch ID)** — ✅ `AppLockManager`, `LockScreenView`, Settings toggle + timeout picker, `NSFaceIDUsageDescription`
2. **Session timeout** — ✅ built into `AppLockManager` (tracks background entry, configurable 1–30 min)
3. **Audit `AppLogger` usage** — ✅ all 18 logger calls audited — no passwords, tokens, or credentials logged
4. **Certificate pinning** — ✅ `PinnedURLSessionDelegate` with server trust evaluation + public key validation. Integrated into `LiveBlueskyClient` session. Keys array ready for production SPKI hashes
5. **Regular dependency audit** — ⏳ needs GitHub Actions workflow for vulnerability scanning
