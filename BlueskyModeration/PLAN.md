# Milestone Plan: Moderation Workflow Expansion

## Goal
Turn the app from a list browser into a practical moderation workspace for Bluesky accounts. The current foundation already covers multi-account auth, profile inspection, list editing, avatar display, and session persistence. This milestone extends that base into faster review, bulk operations, and reusable workflows.

## Scope
In scope for this milestone:
- Bulk member operations on lists
- Direct moderation actions from profile views
- Import/export of handles and list membership
- List comparison and diffing
- Saved searches and local history for recurring review work
- UI polish needed to keep the workspace fast and clear

Out of scope for this milestone:
- Server-side synchronization or cloud backup
- Notifications and background jobs
- Full follower/following analytics dashboard
- Any redesign that would replace the current navigation model

## Phases

### Phase 1: Bulk Member Management
Goal: let the user work on many people at once instead of one row at a time.

Deliverables:
- Multi-select members inside a list
- Bulk add/remove actions
- Bulk selection from search results
- Clear partial-failure reporting per actor

Verification:
- Select several members and remove them in one action
- Search for several handles and add the matches to a list
- Confirm the app reports skipped or failed records without losing the successful ones

### Phase 2: Direct Profile Moderation
Goal: make the profile inspector actionable, not just informational.

Deliverables:
- Block and unblock from profile detail
- Mute and unmute from profile detail
- Shortcuts to add a profile to moderation-oriented lists
- Clear confirmation states for destructive actions

Verification:
- Open a profile and block or unblock it
- Open the same profile again and verify the displayed state updates
- Repeat for mute and unmute

### Phase 3: Import, Export, and Diff
Goal: support review workflows that start outside the app and end in the app.

Deliverables:
- Paste or import handles from plain text and CSV
- Export a list of members for review or archiving
- Compare two lists and show overlap, only-in-left, and only-in-right
- Copy or move selected members between lists

Verification:
- Import a text list and confirm valid handles are resolved
- Export list members and confirm the file contains the expected entries
- Compare two lists and confirm the diff matches the known overlap

### Phase 4: Saved Searches and Local History
Goal: reduce repeated manual work and preserve context across sessions.

Deliverables:
- Save reusable search filters for handles, DIDs, and display names
- Re-run recent searches from a history panel
- Store lightweight local snapshots of list membership
- Show what changed since the last sync

Verification:
- Save a search and restore it after relaunch
- Refresh a list and confirm membership changes are visible in history
- Reopen the app and confirm the last-used search state is still available

### Phase 5: Polish and Release Hardening
Goal: make the new workflows dependable enough for regular use.

Deliverables:
- Better empty states and loading states
- Stronger auth and network error messages
- Accessibility pass on actions and list rows
- Build and runtime verification on the iPhone simulator

Verification:
- Run the app through the common flows without crashes
- Verify the main screens still build and render correctly in simulator
- Confirm all primary actions remain reachable with VoiceOver-friendly labels

## Success Criteria
This milestone is done when:
- The app can handle bulk moderation workflows without forcing one-by-one edits
- Profile screens can perform the core moderation actions directly
- Lists can be imported, exported, and compared with low friction
- Repeated review work can be saved and resumed
- The app still builds cleanly and remains stable on iPhone simulator

## Execution Order
1. Bulk member management
2. Direct profile moderation
3. Import, export, and diff
4. Saved searches and local history
5. Polish and release hardening

## Risks
- Bluesky API behavior may differ across PDS hosts, so auth and request routing should stay host-aware.
- Bulk actions need careful partial-failure handling so a single bad record does not block the entire operation.
- Import and diff features can easily become noisy, so the UI must stay compact and readable.
