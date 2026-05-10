# HIG & Accessibility Audit — BlueskyModeration

## RootView.swift

**Onboarding sheet is non-dismissable (line 77).** Users who trigger it are trapped — no close button, no swipe-to-dismiss. Add a close button in the toolbar or use `\.interactiveDismiss`.

**Hardcoded font size `48` (line 83).** Doesn't scale with Dynamic Type. Use `.font(.system(size:relativeTo:))` or a semantic style.

**`OnboardingRow` has no accessibility labels (lines 100-103).** VoiceOver reads raw text but the icon's meaning is lost. Add `.accessibilityElement(children: .combine)`.

**`.accessibilityLabel("Quick switch account")` lacks a hint (line 61).** Add `.accessibilityHint("Opens account switcher to change or manage accounts")`.

---

## InfoView.swift — Highest Concentration of Issues

**Hardcoded `white.opacity(0.55)` text across the view (lines 80-81, 124-126, 152-153, 284-285, 314-315, 338-339, 366-368).** Fails WCAG AA (4.5:1 contrast). On dark background, 55% opacity white is ~2.8:1. Minimum for 11pt caption text should be 4.5:1. Raise to ≥0.75.

**`Link` views have no accessibility labels (lines 112, 221-225, 229, 242, 246).** VoiceOver reads full URLs instead of describing the action. Add `.accessibilityLabel("View on GitHub")`, `.accessibilityLabel("Privacy Policy")`, etc.

**Hardcoded font sizes (lines 65, 83).** `.font(.system(size: 36))` and `.font(.system(size: 48))` ignore Dynamic Type. Use `.font(.largeTitle)` or `.font(.system(size:relativeTo:))`.

**Caption text at `white.opacity(0.85)` on claim tiles (line 284-285).** Contrast concern on dark gradient background.

**Background uses hardcoded dark colors (lines 372-397).** Renders incorrectly in light mode. Either use semantic colors that adapt, or explicitly lock to dark mode with `.preferredColorScheme(.dark)`.

**Segmented `Picker` lacks context (lines 16-18).** VoiceOver reads it as "Section" but the tabs lack descriptive context.

---

## StatePanels.swift

**`ErrorRetryBanner` retry button (lines 56-59).** No `.accessibilityLabel` for the warning icon. Add `.accessibilityLabel("Retry: \(message)")`.

**`LoadingPanel` (lines 3-17).** `.accessibilityElement(children: .combine)` is good but no actual label. If `message` is custom, it should be announced.

**`StatusChip` tap target (lines 107-108).** `.padding(.vertical, 3)` creates a ~21pt target, well below 44pt minimum. Increase to `.padding(.vertical, 12)`.

**`OnboardingRow` (lines 161-180).** No `.accessibilityElement(children: .combine)` or label. VoiceOver reads icon and text separately.

---

## BlueskyActorRow.swift

**Good `.accessibilityLabel` (line 23).** But `.padding(.vertical, 4)` makes the row tap target small (~8pt padding + text height). When used inside `NavigationLink`/`Button`, the parent provides the hit area, but if standalone the tap target is insufficient. Ensure parent containers add enough padding.

---

## AccountChip.swift

**`.padding(.vertical, 6)` (lines 20-21).** Vertical tap target is ~27pt, below 44pt. When tappable, users will struggle to tap it.

---

## Dynamic Type Issues (Cross-cutting)

`@ScaledMetric` is used on 7 avatar sizes — good. Missing items:

- No `@ScaledMetric` for spacing in custom grids or card layouts
- `ListsView` and `ProfileInspectorView` cap `.dynamicTypeSize` at `.xxxLarge`. Consider whether `.accessibilityExtraLarge` would work instead.

---

## Touch Target Issues (Cross-cutting)

| Element | Vertical padding | Est. height | Rule |
|---------|-----------------|-------------|------|
| `StatusChip` | 3pt | ~21pt | Need 44pt min |
| `AccountChip` | 6pt | ~27pt | Need 44pt min |
| `BlueskyActorRow` | 4pt | ~32pt | Marginal inside NavigationLink |
| `OnboardingRow` | 0pt | ~36pt | Add padding to meet 44pt |
| `HelpSection` info icons | 0pt | ~16pt icons | Not buttons, but `.frame(minWidth: 44)` |

---

## Dark Mode

- `Color.skyPrimary` (0.07, 0.53, 0.98) and `skyAccent` have no dark variants
- `InfoView.swift` hardcodes dark backgrounds — broken in light mode
- Most of the app uses system semantic colors (`.primary`, `.secondary`, `.systemBackground`) which adapt automatically — good
- The `.opacity(0.12)` tinted backgrounds (`StatusChip`, feature cards) need checking in dark mode — may become invisible

---

## Reduce Motion

No usage of `@Environment(\.accessibilityReduceMotion)` anywhere. If any animations exist (sheet presentations, list animations, symbol effects), they should be disabled when Reduce Motion is active.

---

## Bold Text

No usage of `@Environment(\.legibilityWeight)` or `UIAccessibility.isBoldTextEnabled` for custom rendering.

---

## Navigation

**No `NavigationSplitView` for iPad.** Push navigation works but doesn't use the available screen width. A split view would better utilize iPad canvas.

**Tab bar stays visible** — good, per HIG.

---

## Summary by Priority

### Must fix (CRITICAL)
1. **InfoView hardcoded dark colors** — add `.preferredColorScheme(.dark)` or make adaptive
2. **`white.opacity(0.55)` text fails WCAG AA** — raise to ≥0.75 for 4.5:1 on dark backgrounds
3. **InfoView Links have no `.accessibilityLabel`** — VoiceOver reads full URLs
4. **Onboarding sheet is non-dismissable** — add close button or interactive dismiss
5. **`StatusChip` 3pt vertical padding** — 21pt target fails 44pt minimum

### Should fix (HIGH)
6. **InfoView hardcoded font sizes** — replace with dynamic text styles
7. **`OnboardingRow` lacks accessibility labels** — use `.accessibilityElement(children: .combine)`
8. **`dynamicTypeSize` caps at `.xxxLarge`** — consider raising to `.accessibilityExtraLarge`
9. **`ErrorRetryBanner` missing accessibility labels** — label the warning icon and retry button

### Good to fix (MEDIUM)
10. **Reduce Motion not handled** — wrap animations in `reduceMotion` check
11. **`AccountChip` 6pt vertical padding** — increase tap target
12. **No `NavigationSplitView` for iPad** — better use of large screen
13. **Custom colors need dark variants** — define in asset catalog or use `UIColor` equivalents
