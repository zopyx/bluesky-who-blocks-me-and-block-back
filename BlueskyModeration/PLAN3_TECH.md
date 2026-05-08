# PLAN3 Technical Specification and Roadmap

## Objective
Translate the product-quality goals in `PLAN3.md` into an implementation-focused roadmap for the next version of the app. The target is a stable, maintainable iOS moderation tool that feels polished in daily use and can keep evolving without feature work collapsing into giant files and fragile state.

## Current Baseline

### Runtime and Build
- Platform: iOS 17+
- Language: Swift 6
- UI stack: SwiftUI
- App structure: single application target in `project.yml`
- Current DI model: shared `@EnvironmentObject` instances from `BlueskyModerationApp`

### Current Feature Shape
- App shell and tabs: `Sources/App`
- Accounts and auth: `Sources/Features/Accounts`, `AccountStore`, `KeychainService`
- Moderation and lists: `Sources/Features/Lists`
- Profile inspection: `Sources/Features/Profile`
- Network and Bluesky integration: `LiveBlueskyClient`
- Local workspace state and audit data: `ModerationWorkspaceStore`

### Current Technical Risks
- `LiveBlueskyClient.swift` is a 1k+ line service mixing auth, transport, endpoint logic, DTO mapping, and retry behavior.
- `ListDetailView.swift` and `ListDetailViewModel.swift` are each 1k+ lines and own too many responsibilities.
- Workspace persistence, snapshot history, navigation intent, and recent activity are coupled in one store.
- There is currently no automated test target configured in `project.yml`.
- Most quality safeguards are manual and local to feature files rather than enforced through reusable primitives.

## Product Engineering Goals
This version should deliver the following technical qualities:
- Predictable async state with no stale-response or overlapping-task regressions in core flows.
- Small enough feature modules that changes can be made without editing one giant file.
- Clear distinction between live network actions, local-only audit data, and transient UI state.
- Fast enough list and search interactions for real moderation sessions with large lists.
- A release process supported by automated tests, targeted instrumentation, and a repeatable manual checklist.

## Non-Goals
- Cloud sync across devices
- Multi-user/team collaboration
- Cross-platform expansion beyond the current iPhone target
- Replacing the app with a heavy architectural framework

## Technical Principles
1. Keep SwiftUI simple at the view layer.
   Views should describe layout and bind state, not coordinate business logic.

2. Split domain logic by workflow, not by arbitrary utility extraction.
   The main cuts should follow moderation workflows: list browsing, member operations, imports, diffs, profile moderation, audit/history.

3. Separate durable state from transient state.
   Persist only what improves user continuity or auditability. Keep loading, selection, and alert state local to the active feature.

4. Normalize async operations.
   Search, pagination, refresh, bulk actions, and authentication refresh should share clear cancellation, deduplication, and progress semantics.

5. Add tests where state transitions are business-critical.
   Focus first on reducers/services that can be validated without UI automation.

## Target Architecture

### App Layer
- `BlueskyModerationApp`
  - Continues to create root stores/services.
  - Moves toward explicit dependency composition rather than letting feature code reach into broad global state.

- `RootView`
  - Remains the tab shell.
  - Stops using persistent workspace state as the primary navigation bus where a local intent object is sufficient.

### Domain and Service Layer
Replace the single large live client with focused components behind protocols:
- `BlueskySessionService`
  - Session restore
  - Access token refresh
  - Authenticated request execution

- `BlueskyListService`
  - Fetch lists
  - Fetch paged members
  - Add/remove members
  - Export-compatible list data fetches

- `BlueskyActorService`
  - Search actors
  - Resolve handles
  - Profile lookup

- `BlueskyModerationService`
  - Block/unblock
  - Mute/unmute
  - Membership lookup across lists

- `BlueskyRequestExecutor`
  - Shared transport, JSON encoding/decoding, error mapping, retry policy

The existing `LiveBlueskyClient` can become a thin facade or adapter while the internals are moved into smaller services.

### Persistence Layer
Split `ModerationWorkspaceStore` into clearer responsibilities:
- `WorkspacePreferencesStore`
  - Selected tab
  - Saved and recent searches
  - Lightweight app preferences

- `ModerationAuditStore`
  - Snapshot history
  - Operation history
  - Diff export metadata if needed

- `WorkspaceCoordinator`
  - Cross-tab intents such as “open profile for actor”
  - Short-lived navigation requests

This keeps persistent user defaults/data separate from ephemeral navigation coordination.

### Feature Layer
Reshape large feature modules into workflow-focused view models:

- Lists
  - `ListsDashboardViewModel`
  - `ListsCatalogViewModel`
  - `ListDetailViewModel`
    - reduced to screen composition and high-level orchestration
  - `ListMembersController`
    - pagination, selection, add/remove/retry operations
  - `ListImportController`
    - parse, classify, preview, commit import items
  - `ListDiffController`
    - compare, select buckets, export diff
  - `ListHistoryController`
    - snapshots, comparisons, recent history

- Profile
  - `ProfileInspectorViewModel`
    - search and route to detail
  - `ProfileModerationViewModel`
    - block/mute/list membership actions

### UI Layer
Adopt a more deliberate component split:
- Reusable state surfaces
  - loading panel
  - empty state panel
  - error/retry banner
  - progress footer / batch progress card
  - status chips and badges

- Reusable workflow sections
  - import preview list
  - diff summary panel
  - operation log card
  - snapshot comparison card

The goal is not to build a design system for its own sake, but to stop each screen from inventing its own layout and feedback patterns.

## Cross-Cutting Technical Work

### Async Operation Model
Introduce consistent patterns for:
- cancellation-aware searches
- request coalescing where repeat fetches are common
- task identity checks before applying results
- overlapping-task guards for destructive actions
- observable progress for batches and imports

Recommended implementation:
- small `LoadableState<Value>` style enum or dedicated state structs where useful
- task tokens / query tokens for search
- dedicated operation IDs for bulk jobs and retries

### Error Model
Add a normalized app-level error mapping:
- authentication expired
- network unavailable / timeout
- decoding or unexpected server response
- rate limit / server refusal
- validation or user-input issue
- partial batch failure

Every core workflow should decide:
- what the user sees
- whether retry is possible
- whether the failure is local-only or mutates live Bluesky state partially

### Instrumentation
Add lightweight timing and counters for:
- list load duration
- next-page fetch duration
- actor search duration
- import resolution duration
- batch operation duration
- diff generation duration

Keep instrumentation local and simple at first, using structured logging or debug-only counters that can support profiling and manual QA.

### Accessibility
Technical acceptance should include:
- stable accessibility labels/values for moderation state
- Dynamic Type validation in main list and profile flows
- non-color-only status indicators
- VoiceOver-friendly summaries for batch and destructive actions

## Testing Strategy

### Required Project Changes
- Add a unit test target to `project.yml`
- Add at least one UI test target if the simulator pass becomes part of release gating

### Priority Unit Tests
1. `ListImportController`
   - duplicate collapse
   - already-present classification
   - unresolved handle classification
   - preview-to-commit filtering

2. `ListMembersController`
   - page append behavior
   - selection semantics
   - batch add/remove progress and retry handling
   - stale page result rejection when context changes

3. `ListDiffController`
   - bucket generation
   - export payload correctness
   - action selection by bucket

4. `ModerationAuditStore`
   - snapshot deduplication
   - retention trimming
   - recent operation ordering

5. `ProfileInspectorViewModel` and `ProfileModerationViewModel`
   - stale search suppression
   - cancellation handling
   - moderation action state updates

6. `BlueskyRequestExecutor` / service adapters
   - auth refresh retry
   - response decoding and error mapping

### Manual Release Checklist
The final milestone should include a documented pass over:
- account add/remove and session restore
- initial list load and pagination
- bulk add/remove/retry
- import preview and commit
- compare, move/copy, diff export
- profile lookup and moderation actions
- app relaunch and restored local state
- no-op refreshes vs meaningful history changes
- offline or failed-network behavior

## Delivery Roadmap

### Phase T1: Foundations and Safety Rails
Goal: make future refactors safer before changing major features.

Deliverables:
- Add unit test target in `project.yml`
- Add shared preview/test fixtures for actors, lists, and memberships
- Introduce normalized app error type
- Introduce lightweight logging/instrumentation hooks
- Document release checklist skeleton

Exit criteria:
- Tests run locally
- At least a few high-value non-UI tests exist
- New feature work can target reusable state and error primitives

### Phase T2: Network and Service Decomposition
Goal: break backend code into smaller units without changing behavior.

Deliverables:
- Extract `BlueskyRequestExecutor`
- Extract session/auth refresh logic
- Extract list, actor, and moderation services
- Keep compatibility through a facade or adapter
- Improve decode failure diagnostics

Exit criteria:
- `LiveBlueskyClient.swift` is materially smaller or reduced to facade responsibilities
- Endpoint behavior is covered by focused service tests
- Errors carry enough context for debugging

### Phase T3: Workspace and Persistence Separation
Goal: untangle audit history, preferences, and cross-screen intent.

Deliverables:
- Split `ModerationWorkspaceStore`
- Move transient navigation intents out of durable persistence
- Migrate saved/recent search behavior cleanly
- Preserve backward-compatible local data migration where needed

Exit criteria:
- Each store has a narrow reason to change
- Relaunch behavior remains stable
- Cross-tab actions do not rely on broad mutable shared state

### Phase T4: List Feature Refactor
Goal: reduce the giant list detail feature into maintainable workflow modules.

Deliverables:
- Extract import controller
- Extract diff controller
- Extract history controller
- Extract member operation controller
- Split `ListDetailView` into major section views

Exit criteria:
- `ListDetailView.swift` and `ListDetailViewModel.swift` are substantially smaller
- Bulk operations, imports, diffs, and history can evolve independently
- Existing PLAN2 functionality remains intact

### Phase T5: UX-State and Async Reliability Pass
Goal: standardize loading, retry, cancellation, and progress behavior.

Deliverables:
- Shared search token pattern across list and profile flows
- Shared retry/pending-state behavior for destructive actions
- Consistent empty/loading/error views
- Progress surfaces for batch jobs and long-running imports

Exit criteria:
- Core flows use consistent state transitions
- Repeated taps and overlapping tasks are safely handled
- No stale response bug class remains in active workflows

### Phase T6: Performance and Rendering Optimization
Goal: keep the app responsive during real moderation sessions.

Deliverables:
- Profile main-thread activity during list loads and diff generation
- Optimize list rendering and section updates
- Reduce redundant fetches and reloads
- Validate snapshot/history cost under repeated use

Exit criteria:
- Large-list interactions stay responsive
- Profiling shows fewer redundant operations
- No obvious UI hitching in common flows

### Phase T7: Accessibility, Design Systemization, and Polish
Goal: make the UI feel deliberate and robust.

Deliverables:
- Shared visual primitives for cards, status chips, progress, and empty states
- Accessibility labels and Dynamic Type pass across major screens
- Dashboard information hierarchy cleanup
- Refined wording and feedback text

Exit criteria:
- Major screens present a coherent visual language
- Accessibility baseline is met in moderation and profile flows
- The app communicates live-vs-local actions clearly

### Phase T8: Release Candidate Hardening
Goal: turn the milestone into a releasable version.

Deliverables:
- Full simulator regression pass
- Test gap closure for critical paths
- Bug-bash fixes
- Final Info/Settings/privacy/trust review
- Release notes and known limitations

Exit criteria:
- No blocking regressions in core workflows
- Automated tests cover critical state transitions
- Manual pass is repeatable and documented

## Success Metrics
- Largest feature files reduced below roughly half their current size or split into bounded modules.
- A test suite exists and covers the highest-risk workflow logic.
- Search, pagination, import, diff, and bulk-action flows share clear async behavior.
- Dashboard, list detail, and profile screens use consistent loading/error/progress surfaces.
- The next feature can be added without expanding a 1k+ line file.

## Recommended Implementation Order
1. T1 Foundations and Safety Rails
2. T2 Network and Service Decomposition
3. T3 Workspace and Persistence Separation
4. T4 List Feature Refactor
5. T5 UX-State and Async Reliability Pass
6. T6 Performance and Rendering Optimization
7. T7 Accessibility, Design Systemization, and Polish
8. T8 Release Candidate Hardening

## Immediate Next Actions
1. Add the test target to `project.yml`.
2. Extract a shared request executor from `LiveBlueskyClient`.
3. Carve import and diff responsibilities out of `ListDetailViewModel`.
4. Split workspace persistence from cross-tab navigation state.
5. Start the first regression tests around snapshot history and stale search handling.
