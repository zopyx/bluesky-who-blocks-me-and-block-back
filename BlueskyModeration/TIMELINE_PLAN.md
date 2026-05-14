# Timeline Plan

## Objective

Turn the current beta Timeline into a first-class, high-trust app surface with:

- strong correctness under refresh, pagination, and feed switching
- modern, account-scoped architecture
- fast, readable, moderation-aware UX
- enough feature depth to justify frequent use
- test coverage that protects the core interaction model

Target quality:

- `9/10` for UX
- `9/10` for feature completeness within current app scope
- `8.5/10` to `9/10` for maintainability and architecture

## Current Gaps

- feed selection is not account-scoped
- feed switching does not reliably trigger reload semantics
- pagination depends on the last visible row
- muted/hidden items can interfere with pagination flow
- timeline actions rely on full refresh instead of local optimistic mutation
- new post detection is count-based rather than identity-based
- Timeline is presented as a beta modal instead of a primary navigation surface
- test coverage for Timeline behavior is effectively absent
- newer Timeline localization keys are incomplete outside English

## Product Goals

The finished Timeline should feel:

- persistent rather than disposable
- fast to scan
- low-friction to act on
- resilient when network conditions are imperfect
- personalized per account
- useful for both passive reading and moderation workflows

## Phase 1: Correctness And State Ownership

### Goals

- make Timeline behavior reliable
- remove fragile local ownership patterns
- fix feed switching, pagination, and filtered-tail issues

### Work

1. Move Timeline dependencies out of `FeedTimelineViewModel`.
   Inject feed preferences, muted words, analytics, and repository dependencies from app-level composition.

2. Make feed selection account-scoped.
   Namespace persistence by active account identifier or DID.

3. Reload automatically on feed change.
   Changing a feed must clear cursor state, reset visible entries, and fetch the selected feed immediately.

4. Fix pagination triggering.
   Remove dependency on the last rendered row and use a footer/sentinel trigger instead.

5. Filter before rendering.
   Build a filtered/visible entries projection so hidden items do not break pagination or UI semantics.

6. Replace count-based new-post logic.
   Detect new posts using URIs and insertion order rather than comparing entry counts.

### Acceptance Criteria

- switching from Following to a custom feed updates both title/chip state and actual rendered posts
- switching accounts preserves separate feed choices
- muted words do not prevent loading the next page
- timeline can paginate even when the last fetched entry is filtered out
- new post indicator reflects actual unseen posts by identity
- no Timeline state is owned solely by view-local stores that should be shared or persisted

### Likely Files

- `Sources/Features/Timeline/FeedTimelineView.swift`
- `Sources/Features/Timeline/FeedTimelineViewModel.swift`
- `Sources/Features/Timeline/FeedPickerView.swift`
- `Sources/Domain/Services/FeedStore.swift`
- `Sources/App/AppDependencies.swift`

## Phase 2: Primary Timeline UX

### Goals

- promote Timeline from beta utility to a first-class surface
- improve readability, loading, error handling, and continuity

### Work

1. Promote Timeline into primary navigation.
   Prefer a top-level destination over a profile-launched beta sheet.

2. Preserve state across navigation.
   Restore scroll position, selected feed, and session context when users return.

3. Redesign the top area.
   Use a proper header with a visible feed selector, refresh state, and quick return to Following.

4. Replace bare loading panels with skeleton rows.

5. Add clear inline error handling.
   Support initial-load failure, refresh failure, and pagination failure with retry affordances.

6. Improve new-post UX.
   Show a sticky control when the user is away from top and new content is available.

7. Refine empty states.
   Distinguish between empty following feed, empty custom feed, filtered content, offline, and API error cases.

8. Improve row ergonomics.
   Ensure reliable tap targets, clearer action grouping, and less accidental navigation.

### Acceptance Criteria

- Timeline can be reopened without losing user context
- initial load state feels intentional and not blank
- pagination failure does not strand the list
- new-post affordance appears only when relevant and inserts content predictably
- empty/error states communicate the actual problem and next action
- all controls meet iOS touch target expectations

### Likely Files

- `Sources/Features/Timeline/FeedTimelineView.swift`
- `Sources/Features/Lists/Profile/PostRowView.swift`
- `Sources/App/RootView.swift`
- `Sources/Features/Lists/BlueskyProfileView.swift`

## Phase 3: Feature Depth

### Goals

- make Timeline useful as a daily workflow surface
- improve feed control, filtering, and moderation shortcuts

### Work

1. Feed management.
   Add saved feeds, recent feeds, pinned feeds, editable names, and URI validation.

2. Filtering.
   Add toggles for replies, reposts, media only, text only, and other lightweight filters that fit current domain scope.

3. Reading controls.
   Add jump-to-latest, unread separator, compact mode, and optional media-rich mode.

4. Moderation shortcuts.
   Add actions such as mute word from post text, mute author, and hide repost origin where appropriate.

5. Composer integration.
   Improve quick reply, quote, and draft continuity from Timeline actions.

6. Translation and external link handling.
   Make these feel intentional rather than utility-only.

### Acceptance Criteria

- users can return to preferred feeds without manually pasting URIs every time
- users can shape Timeline noise level with lightweight filters
- moderation actions can be initiated from Timeline without leaving the feed
- quick reply and quote flows return users cleanly to the same context
- Timeline supports both scanning and deeper engagement modes

### Likely Files

- `Sources/Features/Timeline/FeedPickerView.swift`
- `Sources/Features/Timeline/FeedTimelineView.swift`
- `Sources/Features/Lists/Profile/PostRowView.swift`
- new Timeline-specific preferences and filtering files under `Sources/Features/Timeline/`

## Phase 4: Architecture Hardening

### Goals

- keep the feature maintainable as it grows
- separate networking, persistence, session state, and UI state cleanly

### Target Structure

#### `TimelineRepository`

Responsibilities:

- fetch Following timeline pages
- fetch custom feed pages
- perform like/repost/reply-related feed mutations or refresh reconciliation
- normalize API responses into Timeline-facing domain models

#### `TimelinePreferencesStore`

Responsibilities:

- persist per-account selected feed
- persist per-account saved feeds
- persist display mode and filter preferences

#### `TimelineSessionStore`

Responsibilities:

- hold current entries
- hold cursor and pagination state
- track unread anchors / top visible post
- manage short-lived in-memory cache for fast feed switching
- restore session state on navigation return

#### `TimelineViewModel`

Responsibilities:

- expose derived UI state
- accept user intents
- coordinate refresh/load-more/switch-feed/update-row actions
- avoid direct persistence or low-level networking logic

### Suggested Timeline State Model

- `initialLoading`
- `loaded`
- `refreshing`
- `loadingMore`
- `loadMoreFailed`
- `empty`
- `failed`
- `exhausted`

### Suggested View Decomposition

- `TimelineScreen`
- `TimelineHeaderView`
- `TimelineListView`
- `TimelineRowView`
- `TimelineFooterStateView`
- `FeedSwitcherView`
- `TimelineEmptyStateView`

### Acceptance Criteria

- view models are thin and intent-focused
- persistence rules are isolated from view code
- pagination and refresh state are explicit rather than inferred from booleans alone
- feature growth does not require stacking more ad hoc state into a single view model

## Performance And Interaction Standards

- like/repost must be optimistic with rollback on failure
- no full-feed refresh after every row action unless reconciliation is required
- analytics persistence must be batched rather than saved once per post mutation
- image and video loading should be near-visible aware
- feed switching should feel immediate, with cache-assisted restoration where appropriate

## Testing Plan

### Unit Tests

- selected feed is isolated per account
- switching feed resets cursor and reloads correct source
- pagination continues when trailing entries are filtered
- new-post detection uses URI identity rather than total count
- optimistic like/repost rollback restores prior row state after failure
- saved/recent feed persistence behaves correctly

### UI Tests

- initial loading state
- empty following feed
- empty custom feed
- pagination failure and retry
- long text post
- mixed media post
- Dynamic Type layout
- RTL rendering

### Integration Tests

- account switching preserves Timeline preferences
- navigation away and back restores session context
- composer flow returns to Timeline correctly
- feed switching under poor network conditions leaves Timeline in recoverable state

## Internationalization

All Timeline strings must be fully localized across the supported language set.

Required work:

- ensure every `timeline.*` key exists in all language files
- avoid mixed-language Timeline UI
- verify pluralization for new post and count-related strings where needed

## Accessibility

Timeline must meet a solid iOS accessibility baseline:

- minimum 44x44 tap targets
- Dynamic Type-safe row layouts
- meaningful VoiceOver labels for action buttons and counts
- reduced-motion friendly transitions
- sufficient contrast in loading, empty, and action states

## Execution Order

1. Phase 1 correctness and state ownership
2. Phase 2 primary UX and navigation
3. Phase 4 architecture hardening where needed to support Phase 3 cleanly
4. Phase 3 feature depth
5. localization and test expansion continuously during each phase, not only at the end

## Delivery Standard

Do not consider Timeline complete until:

- correctness edge cases are covered by tests
- feed selection is account-scoped
- optimistic interaction replaces full-feed churn for primary row actions
- Timeline is discoverable and persistent in navigation
- localization coverage is complete
- the feature feels stable enough to remove the “beta utility” framing

## File Reference Map

- `Sources/Features/Timeline/FeedTimelineView.swift`
- `Sources/Features/Timeline/FeedTimelineViewModel.swift`
- `Sources/Features/Timeline/FeedPickerView.swift`
- `Sources/Domain/Services/FeedStore.swift`
- `Sources/Domain/Services/LiveBlueskyClient.swift`
- `Sources/Features/Lists/Profile/PostRowView.swift`
- `Sources/App/AppDependencies.swift`
- `Sources/App/RootView.swift`

## Summary Table

| Area | Change | Impact |
|------|--------|--------|
| Product | Promote Timeline to a primary surface with durable state and strong reading ergonomics | Makes Timeline habitual, trustworthy, and easier to use |
| Correctness | Fix feed switching, pagination, filtering, and new-post detection | Removes brittle beta behavior and edge-case failures |
| Architecture | Introduce repository/preferences/session separation with injected dependencies | Improves maintainability and supports future feature growth |
| Features | Add saved feeds, filters, moderation shortcuts, and stronger composer integration | Increases utility and daily return value |
| Quality | Add tests, localization completeness, and accessibility coverage | Raises confidence and readiness for broader rollout |
