# UX Master Plan — Rulyx

## Goal

Raise the app's UX quality from roughly 5/10 to 8/10 by fixing product-shell inconsistencies, removing avoidable friction, improving accessibility, and making high-frequency moderation workflows feel fast and intentional on iPhone and iPad.

## Current Reality

The app already has strong feature depth, but the UX is held back by four classes of problems:

1. Product drift
   The app shell, onboarding, and UI tests do not agree on the core navigation model. Some major features exist in code but are not surfaced consistently.

2. Accessibility and localization debt
   Many accessibility labels and hints are hard-coded in English, touch targets are inconsistent, and some screens still have contrast and Dynamic Type issues.

3. Visual inconsistency
   A few screens force dark mode or use one-off styling decisions that do not align with the rest of the app or with system expectations.

4. Workflow heaviness
   Core screens carry too much state and too many presentation responsibilities, which makes the UX harder to refine and easier to regress.

## UX Principles

1. Core moderation tasks must be obvious within 5 seconds.
2. The app shell must reflect the real product, not legacy assumptions.
3. Every user-facing string, including accessibility copy, must be localized.
4. Large screens should get large-screen navigation, not stretched phone flows.
5. High-risk actions must feel safe and high-volume actions must feel efficient.
6. Performance feedback must be immediate, specific, and reversible where possible.

## Success Metrics

1. Zero unreachable top-level features.
2. Zero hard-coded English user-facing strings in `Sources/`.
3. Zero forced color scheme overrides on primary screens unless explicitly justified.
4. All tappable controls meet 44x44pt target guidance.
5. Dynamic Type works through accessibility sizes on core flows.
6. VoiceOver can complete account, lists, profile inspection, and moderation flows.
7. iPad uses split navigation for the main moderation workflow.
8. Critical flows have UI coverage aligned with the shipped navigation model.

## Workstreams

### 1. Product Shell

Objective:
Make navigation, onboarding, and feature exposure coherent.

Problems to solve:
- `RootView` does not expose all major workflows consistently.
- Onboarding references a product shape that the app shell does not match.
- UI tests still assert an older tab structure.

Deliverables:
- Finalize top-level navigation model.
- Restore or intentionally remove the profile-inspection entry point.
- Update onboarding content to match the real app.
- Update UITests to reflect the shipped shell, not historical behavior.

Acceptance criteria:
- Every top-level workflow referenced in onboarding is reachable from the app shell.
- No UI test expects a missing tab or hidden primary feature.

### 2. Accessibility and Localization

Objective:
Make the app usable across languages, assistive technologies, and text sizes.

Problems to solve:
- Hard-coded accessibility labels and hints remain in several views.
- Some controls still rely on small tap targets.
- A few screens still use sizing or contrast choices that work poorly with accessibility settings.

Deliverables:
- Replace remaining hard-coded labels, hints, and helper copy with localization keys.
- Audit touch targets in shared components and list rows.
- Audit Dynamic Type on onboarding, Info, list detail, and profile inspection flows.
- Add explicit VoiceOver verification for core tasks.

Acceptance criteria:
- All user-visible strings in `Sources/` use `loc(...)` or the localization manager.
- Core workflows remain usable at accessibility text sizes.
- VoiceOver labels describe actions, not raw URLs or ambiguous icons.

### 3. Visual System and Theming

Objective:
Remove visual surprises and make styling choices deliberate and system-compatible.

Problems to solve:
- Some major screens force dark mode.
- A few views use custom colors and opacity values with weak contrast discipline.
- The visual style is not yet consistent across feature areas.

Deliverables:
- Remove forced dark mode from primary screens unless product requirements demand it.
- Replace fragile opacity-based text styling with semantic or contrast-verified tokens.
- Define reusable color, spacing, and surface rules for cards, banners, and status chips.
- Re-audit `InfoView` as the highest-risk presentation surface.

Acceptance criteria:
- Main screens adapt correctly to system appearance.
- Contrast-sensitive surfaces pass a manual WCAG-oriented review.
- Shared components use common styling tokens instead of one-off values.

### 4. Core Workflow Simplification

Objective:
Make high-frequency moderation flows faster and easier to understand.

Problems to solve:
- `ListsView`, `ProfileInspectorView`, and other large views mix orchestration with rendering.
- Bulk and inspection flows surface a lot of capability, but not always with a clear task hierarchy.
- State-heavy screens are harder to polish iteratively.

Deliverables:
- Reduce top-level screen complexity by extracting sections, toolbar logic, and presentation coordinators.
- Make primary actions more visually dominant than secondary or advanced actions.
- Standardize loading, empty, error, and retry behavior across list and profile flows.
- Ensure long-running moderation tasks always expose progress and recovery affordances.

Acceptance criteria:
- Core screens have a clearer visual hierarchy.
- Repeated patterns for loading, error, and retry look and behave the same.
- High-volume tasks can be understood without reading the entire screen.

### 5. iPad Experience

Objective:
Stop treating iPad as a scaled-up phone.

Problems to solve:
- Main moderation navigation still uses stacked push flows on large screens.
- Dense moderation work benefits from persistent context and side-by-side detail.

Deliverables:
- Introduce `NavigationSplitView` for the main list/detail workflow.
- Preserve selection state and detail context across list changes.
- Audit popovers, sheets, and account switching behavior on iPad layouts.

Acceptance criteria:
- Main moderation workflow uses split navigation on iPad.
- Switching between lists and detail views does not feel modal or cramped.

### 6. UX Reliability

Objective:
Make the UX harder to regress.

Problems to solve:
- The current test suite is partly stale and too shallow in UX-critical areas.
- Product-shell regressions were able to survive in the codebase.

Deliverables:
- Replace stale UI smoke assumptions with flow-based tests.
- Add UI coverage for account setup, account switching, list loading, member operations, and profile inspection.
- Add explicit regression checks for localization-sensitive navigation labels where practical.

Acceptance criteria:
- UI tests validate real primary tasks instead of only checking that screens exist.
- Navigation changes that break core flows fail CI.

## Phased Roadmap

### Phase 1. Stabilize the Product Shell

Focus:
- Resolve tab/navigation drift.
- Update onboarding to reflect reality.
- Align UI tests with shipped navigation.

Expected impact:
- Immediate clarity improvement for users and contributors.
- Removes the most visible trust-damaging inconsistencies.

### Phase 2. Accessibility and Localization Cleanup

Focus:
- Remove remaining hard-coded user-facing strings.
- Fix touch targets, labels, hints, and Dynamic Type issues in primary flows.

Expected impact:
- Large UX gain with low product risk.
- Improves usability across all supported languages.

### Phase 3. Visual System Cleanup

Focus:
- Remove forced dark mode.
- Normalize contrast and shared styling.
- Rework `InfoView` into a fully compliant screen.

Expected impact:
- The app feels more intentional and more native.

### Phase 4. Core Flow Simplification

Focus:
- Refactor large screens around user tasks.
- Standardize feedback states and action hierarchy.

Expected impact:
- Faster moderation workflows.
- Lower future regression risk.

### Phase 5. iPad Upgrade

Focus:
- Introduce `NavigationSplitView`.
- Tune detail persistence and multi-pane behavior.

Expected impact:
- Significant improvement for power users and long moderation sessions.

### Phase 6. UX Regression Net

Focus:
- Expand flow-based UI tests.
- Lock in the improved shell and workflows.

Expected impact:
- Prevents backsliding after the UX overhaul.

## Priority Order

1. Product shell consistency
2. Accessibility and localization debt
3. Forced dark mode and contrast cleanup
4. Core workflow simplification
5. iPad navigation model
6. UX-focused UI test coverage

## File-Level Starting Points

- App shell and onboarding:
  `Sources/App/RootView.swift`
  `Sources/App/BlueskyModerationApp.swift`

- Highest-risk UX surfaces:
  `Sources/App/InfoView.swift`
  `Sources/Features/Lists/ListsView.swift`
  `Sources/Features/Profile/ProfileInspectorView.swift`
  `Sources/Features/Lists/ListDetailView.swift`

- Shared accessibility and interaction surfaces:
  `Sources/Shared/Components/StatePanels.swift`
  `Sources/Shared/Components/BlueskyActorRow.swift`
  `Sources/Shared/Components/AccountChip.swift`
  `Sources/Shared/Components/LockScreenView.swift`

- Supporting state and tests:
  `Sources/Domain/Services/WorkspacePreferencesStore.swift`
  `UITests/BlueskyModerationUITests/BlueskyModerationUITests.swift`
  `HIG-AUDIT.md`

## Non-Goals

1. Rebranding the product.
2. Rewriting the entire architecture before visible UX fixes land.
3. Adding new advanced moderation features before core flows are coherent.
4. Treating visual polish as a substitute for accessibility or task clarity.

## Exit Condition

This plan is complete when the app shell is coherent, primary workflows are reachable and well-instrumented, accessibility and localization issues are no longer systemic, iPad has a first-class moderation layout, and the UI test suite protects the improved experience from regression.
