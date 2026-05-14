# UI/UX & Accessibility Recommendations

Based on codebase analysis of the BlueskyModeration iOS app. Each recommendation targets specific files and patterns observed in the source.

---

## 1. Design Token System & Rich Color Semantics

**Problem:** `Sources/Shared/Theme/Color+BlueskyModeration.swift` defines only 4 flat colors (`skyPrimary`, `skyAccent`, `skyOrange`, `skyPurple`) with no semantic system. WCAG AA contrast compliance is not guaranteed across light/dark modes. `GlassSupport.swift` provides iOS 26 glass effects but they're used in only one view (`BlueskyProfileView.swift:528`).

**Recommendation:**
- Add semantic colors with verified contrast ratios: `successGreen`, `warningOrange`, `errorRed`, `infoBlue` — each with foreground, background, and muted variants
- Create a surface hierarchy: `surfacePrimary`, `surfaceSecondary`, `surfaceTertiary` (move away from direct `Color(.secondarySystemFill)` in `AppStyling.swift`)
- Define gradient presets for cards and section headers using the existing sky palette
- Adopt `glassEffect`/`Material` backgrounds broadly: section headers, floating action buttons, detail cards
- **Files affected:** `Color+BlueskyModeration.swift`, `AppStyling.swift`, `GlassSupport.swift`, all view files

**Impact:** Immediate visual hierarchy lift, accessible contrast, dark mode confidence, reduced boilerplate.

---

## 2. Remove Dynamic Type Caps — Extend to `accessibility5`

**Problem:** `ListsView.swift:213` and `ModerationSplitView.swift:355` force `.dynamicTypeSize(DynamicTypeSize.xSmall...DynamicTypeSize.accessibility1)`, excluding users who need larger text. 50+ uses of `.font(.caption)` / `.font(.caption2)` become illegible at accessibility text sizes. Only 8 `@ScaledMetric` usages exist across the entire app.

**Recommendation:**
- Remove the `.dynamicTypeSize()` cap from list/detail views (or raise to `accessibility5` and offer a compact layout alternative where layout breaks)
- Audit all `.font(.caption)` and `.caption2` instances — replace `caption2` with `caption` and use proper `@ScaledMetric(relativeTo:)` for derived sizes
- Ensure every icon/avatar/tappable area uses `@ScaledMetric` (currently only in `BlueskyActorRow.swift`, `ListRowView.swift`, `AccountRowView.swift`, `AccountChip.swift`, `iPadAccountSwitcher.swift`, `AccountSummaryCard.swift`, `RelationshipsView.swift`)
- **Files affected:** `ListsView.swift`, `ModerationSplitView.swift`, `ListDetailView.swift`, `BlueskyProfileView.swift`, `RelationshipsView.swift`, `BlueskyActorRow.swift`, `ListRowView.swift`

**Impact:** Direct accessibility improvement for visually impaired users — a top-3 a11y failure pattern.

---

## 3. Micro-interactions & Motion Polish

**Problem:** Almost zero animation exists. No list insertion animations, no state transitions, no haptic feedback on actions (except one double-tap easter egg in `BlueskyProfileView.swift:344`). `UIAccessibility.isReduceMotionEnabled` is checked in only one place (profile avatar preview, line 63).

**Recommendation:**
- Add `.scrollTransition(.interactive)` on list rows for parallax/tilt effects (iOS 18+)
- Use `.matchedGeometrySource`/`.matchedGeometryDestination` for hero transitions (avatar → preview, list row → detail)
- Add spring animations on state changes: card selection, toggle switches, sheet presentation
- Add `SensoryFeedback` for moderation actions: block, mute, add/remove from list, import complete
- Wrap all motion in `UIAccessibility.isReduceMotionEnabled` checks — create a shared `appAnimation(_:)` helper that returns `nil` or `default` based on the preference
- **Files affected:** `ListDetailView.swift`, `BlueskyProfileView.swift`, `ListsView.swift`, `ListDetailMembersSection.swift`, `ListDetailSearchSection.swift`, `RelationshipsView.swift`, `AppStyling.swift` (new animation helper)

**Impact:** Transforms feel from "functional data tool" to "polished native app" without sacrificing accessibility.

---

## 4. Consistent Typographic Scale

**Problem:** 360+ inline `.font()` calls across the codebase with 9 different text styles used inconsistently (`caption`, `caption2`, `subheadline`, `headline`, `body`, `callout`, `title3`, `title`, `largeTitle`). No system-wide scale; font decisions are repeated per-view.

**Recommendation:**
- Define `AppTextStyle` enum with semantic roles:
  - `title` → `.title2.weight(.bold)`
  - `heading` → `.headline.weight(.semibold)`
  - `body` → `.body`
  - `caption` → `.caption.weight(.semibold)`
  - `statistic` → `.title3.weight(.semibold).monospacedDigit()`
  - `label` → `.subheadline`
- Create a `.appFont(_:)` view modifier extension
- Replace raw `.font(.caption.weight(.semibold))` with `.appFont(.caption)` throughout
- Apply `.dynamicTypeSize(...)` at the root view level only, not per-view
- **Files affected:** `AppStyling.swift` (new file or extension), every view file (global find-replace for font calls)

**Impact:** Dramatically reduces visual noise, ensures readability at all text sizes, simplifies maintenance.

---

## 5. Screen Reader & Focus Management

**Problem:** The app has good `accessibilityLabel`/`accessibilityHint` coverage (159 instances) but critical gaps remain:

- `.buttonStyle(.plain)` buttons in the relationships grid (`ModerationSplitView.swift:379`, `ListsView.swift:294`) lack `.accessibilityAddTraits(.isButton)` — VoiceOver users don't perceive them as interactive
- No `@FocusState` on search fields (`ListDetailSearchSection.swift`, `ListDetailMembersSection.swift`) — keyboard users can't tab-to-search
- No `accessibilitySortPriority` on the 2-column relationship grids — VoiceOver reads left-to-right row-by-row instead of top-to-bottom column-by-column
- Alert action buttons lack `.accessibilityInputLabels` — ok/cancel/delete need short voice input labels
- No live region announcements for async operations (bulk progress, import results, export completion)
- No `accessibilityRotor` for navigating between sections (members, search, comparison, snapshots)

**Recommendation:**
- Add `.accessibilityAddTraits(.isButton)` to all `.buttonStyle(.plain)` interactive rows
- Add `@FocusState` to search fields with keyboard shortcut support
- Apply `.accessibilitySortPriority` to columnar layouts (higher priority = read first)
- Add `.accessibilityInputLabels(["OK"], ["Cancel"], ["Delete"])` to alert buttons
- Use `.accessibilityAnnouncement()` via `UIAccessibility.post` for live region updates
- Add section rotors in `ListDetailView.swift` for quick navigation
- **Files affected:** `ListsView.swift`, `ModerationSplitView.swift`, `ListDetailView.swift`, `ListDetailSearchSection.swift`, `ListDetailMembersSection.swift`, `ListDetailComparisonSection.swift`, `BlueskyProfileView.swift`, `RelationshipsView.swift`

**Impact:** Moves from good-enough accessibility to truly inclusive — critical for a moderation tool used for hours at a time by power users.
