# Milestone Plan: Moderator Throughput and Scale

## Goal
Turn the current moderation workspace into something that holds up under larger lists, longer review sessions, and higher-volume bulk actions.

## Scope
In scope for this milestone:
- Pagination and large-list handling
- Stronger import review and resolution flows
- Actionable list diff workflows
- Safer bulk operations with retry and auditability
- A lightweight moderation dashboard for faster entry into active work
- Deeper local history for list changes over time

Out of scope for this milestone:
- Cloud sync or cross-device state sharing
- Background refresh or push notifications
- Full analytics or follower-network intelligence
- Multi-user collaboration

## Phases

### Phase 1: Pagination and Large Lists
Goal: make the app usable when lists or searches exceed the current single-page assumptions.

Deliverables:
- Cursor-based pagination for list members
- Cursor-based pagination for actor search where available
- Incremental loading UI with loading-more state
- Clear count and progress feedback during long fetches

Verification:
- Open a large list and load multiple pages without duplicate rows
- Scroll through paginated members and confirm selection state remains stable
- Search broad terms and confirm additional results can be loaded

### Phase 2: Import Review and Resolution
Goal: make imports safer and less noisy before changes hit a live list.

Deliverables:
- Import preview screen before commit
- Grouping for valid, duplicate, unresolved, and already-present entries
- Import options such as skip existing or import only new accounts
- Better parsing for pasted text, CSV, and Bluesky profile URLs

Verification:
- Import a mixed text/CSV payload and confirm each entry is classified correctly
- Confirm unresolved items do not block valid imports
- Re-run the same import and verify duplicates are skipped cleanly

### Phase 3: Actionable Diff Workflows
Goal: move from summary-only comparison to direct action on diff results.

Deliverables:
- Dedicated diff result sections for overlap, only-in-left, and only-in-right
- Selection actions inside diff results
- Copy selected diff members between lists
- Export diff results to CSV

Verification:
- Compare two known lists and confirm the diff buckets are correct
- Copy only the only-in-right members into the active list
- Export a diff and confirm the file contents match the shown results

### Phase 4: Safer Bulk Operations
Goal: make large moderation actions more dependable and easier to recover from.

Deliverables:
- Retry-failed support for batch add/remove/copy/move/import actions
- Operation progress UI for long-running batches
- Local operation log with timestamped success/failure summary
- Better partial-failure messaging for repeated actions

Verification:
- Run a batch with intentional failures and retry only the failures
- Confirm progress updates while the batch is active
- Reopen the app and confirm the last operation summary is still visible locally

### Phase 5: Moderation Dashboard
Goal: reduce navigation overhead by surfacing the most relevant work first.

Deliverables:
- Dashboard tab or dashboard section on the main moderation screen
- Recent list changes summary
- Quick links to largest moderation lists and recent searches
- Shortcuts into import, compare, and profile inspection workflows

Verification:
- Launch the app and reach the most-used moderation flows from one screen
- Confirm recent list changes and saved work items appear correctly
- Switch accounts and verify dashboard content updates to the active context

### Phase 6: Historical Change Tracking
Goal: preserve more than the last snapshot so moderators can review trends over time.

Deliverables:
- Multiple local snapshots per list instead of only latest state
- Simple timeline of membership changes
- Per-list “what changed since” comparison between snapshots
- Retention policy for local snapshot history

Verification:
- Refresh a list multiple times and confirm snapshot history accumulates
- Compare two older snapshots and verify added/removed accounts
- Confirm history remains local and survives app relaunch

## Success Criteria
This milestone is done when:
- Large lists no longer feel truncated or fragile
- Imports are previewed and classified before live mutation
- Diff results can be acted on directly
- Bulk actions provide recovery paths and usable history
- The app surfaces active moderation work faster from launch
- Local history becomes useful for short-term audit and review

## Execution Order
1. Pagination and large lists
2. Import review and resolution
3. Actionable diff workflows
4. Safer bulk operations
5. Moderation dashboard
6. Historical change tracking

## Risks
- Bluesky pagination behavior may differ by endpoint, so cursor handling needs endpoint-specific testing.
- Larger result sets can create SwiftUI performance issues if row identity and batching are sloppy.
- Import preview and diff actions can grow noisy quickly, so the UI needs strict information hierarchy.
- Local audit/history features can become confusing unless retention and naming are explicit.
