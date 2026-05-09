# Bluesky Moderation for iPhone

## Goal

Build a native iPhone app in Xcode that helps a user manage Bluesky lists across multiple accounts. The first shipped feature is a fast overview of:

- user-created lists
- moderation lists
- member count for each list

The app is intentionally narrow in scope at the start: secure multi-account access, fast account switching, and a reliable list inventory screen.

## Product Summary

Working title: `BlueShield` or `Bluesky Moderation`

Primary user:

- a Bluesky user who operates more than one account
- a moderator who maintains lists and moderation lists
- a power user who wants a clean operational view instead of a full social client

Core promise:

- sign in once with multiple Bluesky accounts
- switch accounts instantly
- see all relevant lists for the active account
- understand list size at a glance

## Platform And Implementation

- Platform: iPhone
- IDE: Xcode
- Language: Swift
- UI framework: SwiftUI
- Architecture: MVVM
- Concurrency: `async/await`
- Secure secret storage: Keychain
- Local lightweight cache: SwiftData or file-backed cache layer
- Minimum target: iOS 17+ recommended

## Version 1 Scope

### Included

- add multiple Bluesky accounts
- store `username` and app-specific password securely
- authenticate each account independently
- switch active account from a dedicated account switcher
- fetch all lists and moderation lists for active account
- display list name, purpose/type, and member count
- manual refresh
- loading, empty, and error states

### Not Included Yet

- editing lists
- adding or removing members
- cross-account bulk actions
- push notifications
- analytics
- iPad-specific layout work

## Information Architecture

Use a simple `TabView` with room to grow:

1. `Lists`
2. `Accounts`
3. `Settings`

For the first milestone, only `Lists` and `Accounts` need full implementation.

## Main User Flows

### 1. First Account Setup

1. User opens app.
2. Empty-state screen explains the app needs a Bluesky handle and app password.
3. User enters:
   - handle or username
   - app-specific password
4. App validates credentials against Bluesky.
5. Account is stored locally.
6. App navigates to the `Lists` tab.

### 2. Add Additional Account

1. User opens `Accounts`.
2. Taps `Add Account`.
3. Enters handle and app password.
4. App validates and stores the account.
5. New account appears in the account switcher.

### 3. Switch Active Account

1. User taps the account picker in the navigation bar or the `Accounts` tab.
2. Selects another account.
3. App updates active session context.
4. `Lists` refreshes automatically for the selected account.

### 4. View Lists Overview

1. User lands on `Lists`.
2. App fetches:
   - standard lists
   - moderation lists
3. App groups them into sections.
4. Each row shows:
   - list name
   - list purpose or label
   - member count
   - optional avatar/icon

## UI Concept

### Lists Screen

Navigation title: `Lists`

Top bar:

- leading: active account avatar/initial
- center: screen title
- trailing: refresh button

Optional account switcher pattern:

- tap active account chip in the navigation area
- open a compact sheet with all stored accounts
- current account is visibly marked

Screen layout:

1. Account summary card
2. Section: `Moderation Lists`
3. Section: `Lists`

Each list row:

- list name in primary text
- secondary line for type or description
- trailing badge with member count

Visual style:

- native iOS appearance
- system typography
- `NavigationStack`
- `List` with grouped sections
- clean status badges using semantic colors

### Accounts Screen

Purpose:

- show all stored accounts
- indicate active account
- add new account
- remove account

Each account row:

- handle
- small status indicator
- active badge when selected

Actions:

- `Add Account`
- `Set Active`
- `Remove`

## Technical Concept

### Suggested Project Structure

```text
BlueskyModeration/
  App/
    BlueskyModerationApp.swift
    RootView.swift
  Features/
    Accounts/
      AccountsView.swift
      AddAccountView.swift
      AccountsViewModel.swift
    Lists/
      ListsView.swift
      ListRowView.swift
      ListsViewModel.swift
  Domain/
    Models/
      AppAccount.swift
      BlueskyList.swift
      ModerationList.swift
    Services/
      AuthService.swift
      BlueskyAPIClient.swift
      AccountStore.swift
      KeychainService.swift
  Infrastructure/
    Networking/
    Persistence/
  Shared/
    Components/
    Utilities/
```

### Core Models

`AppAccount`

- id
- handle
- did or account identifier
- session metadata
- createdAt
- lastUsedAt

`BlueskyList`

- id / uri
- name
- description
- purpose
- avatarURL
- memberCount
- kind: `regular` or `moderation`

### State Ownership

`AccountStore`

- owns all saved accounts
- tracks active account
- exposes switch-account action

`AuthService`

- logs into Bluesky
- refreshes sessions if needed
- never exposes raw password outside secure boundaries

`ListsViewModel`

- loads lists for active account
- merges standard and moderation list data for display
- exposes loading/error/empty state

## Security Model

Sensitive data rules:

- app passwords are stored only in Keychain
- do not store raw password in `UserDefaults`
- session tokens, if persisted, should also be stored in Keychain
- account metadata may be stored in SwiftData or lightweight local storage
- remove all secure material when an account is deleted

## Network Layer

The network layer should be isolated behind a `BlueskyAPIClient` protocol so the app can be tested without live network calls.

Responsibilities:

- create authenticated requests for the active account
- fetch list collections
- fetch member counts
- map API responses into app models
- normalize regular lists and moderation lists into one UI shape

Because Bluesky and AT Protocol endpoints may evolve, the concrete endpoint mapping should be verified during implementation against the current SDK or API docs. The concept should treat API integration as an adapter layer, not something embedded in views.

## Member Count Strategy

The first screen depends on accurate member counts. Preferred behavior:

- use count fields returned directly by the API when available
- if counts are not returned directly, fetch per-list membership summaries
- cache recent results briefly to avoid unnecessary repeated calls during account switching

Display rules:

- known count: show number
- loading count: show small spinner or placeholder
- unavailable count: show `-`

## Error Handling

Expected cases:

- invalid app password
- expired session
- network unavailable
- partial fetch failure for one list type

UX behavior:

- blocking auth errors redirect to account repair flow
- transient fetch errors show inline retry
- partial data should still render when possible

## Suggested Milestones

### Milestone 1

- Xcode project setup
- app shell with tabs
- add/remove account flow
- Keychain storage
- active account switcher

### Milestone 2

- authenticated Bluesky API client
- fetch regular lists
- fetch moderation lists
- merge and render both sections

### Milestone 3

- member count accuracy and caching
- pull to refresh
- better empty and error states

### Milestone 4

- detail screen for a single list
- member browsing
- moderation actions

## Acceptance Criteria For First UI

- user can add at least two Bluesky accounts
- user can switch active account without re-entering credentials
- `Lists` screen refreshes when account changes
- screen shows both lists and moderation lists in separate sections
- each visible list row shows a member count or a clear unavailable state
- app remains usable when one fetch fails but the other succeeds

## Recommended First Build

Start with a small vertical slice:

1. create SwiftUI app shell
2. implement secure account storage
3. add account switcher
4. mock the list API with sample JSON
5. build the lists screen against mocked data
6. replace mocks with real Bluesky integration

This reduces risk because the multi-account and UI state model can be validated before the network layer is finalized.

---

# Multi-Provider Support (Bluesky, Eurosky, etc.)

## Goal

Allow users to authenticate against any AT Protocol PDS (Personal Data Server) — not just `bsky.social`. Examples include Eurosky (`eurosky.social`), community-hosted PDS instances, and self-hosted servers.

## Current Architecture

The app already supports multi-PDS at the protocol level:

| Layer | Current behavior | Status |
|-------|-----------------|--------|
| Authentication | `createSession` called on `entrywayURL` (defaults to `bsky.social`), PDS resolved from DID document | ✅ Works for any PDS |
| API routing | All requests use `authSession.pdsURL` from the session | ✅ Automatic |
| Handle resolution | `com.atproto.identity.resolveHandle` queries the entryway, then DID document provides PDS endpoint | ✅ Protocol-level |
| PLC history | `plc.directory/{did}/log/audit` hardcoded | ⚠️ Only works for `did:plc:` |
| Entryway selection | No user-facing way to pick a different entryway | ❌ Hardcoded to `bsky.social` |

## Required Changes

### 1. Custom Entryway URL in Account Setup

The `AddAccountView` needs an optional field for the entryway PDS URL:

```
Handle: [________________]
App Password: [________________]
PDS Entryway (optional): [https://bsky.social]
```

- Default to `https://bsky.social`
- Auto-detect from handle domain when possible (e.g. `@user.eurosky.social` → `https://eurosky.social`)
- Allow manual override for advanced users
- Store the entryway URL per-account

### 2. Auto-Detection from Handle Domain

The handle format `@user.domain.tld` often reveals the PDS:

```
user.bsky.social       → https://bsky.social
user.eurosky.social    → https://eurosky.social
user.mypds.com         → https://mypds.com
```

Detection logic in `authenticationURL(forHandle:)`:

```swift
// Step 1: Extract domain from handle suffix
// Step 2: Try https://<domain> as entryway
// Step 3: Fall back to DID-based resolution
// Step 4: Fall back to bsky.social
```

This already partially exists — handles ending in `.bsky.social` use `entrywayURL`. The domain-specific logic should be generalized.

### 3. DID Method Resolution

The PLC directory only works for `did:plc:` DIDs. Other DID methods need different approaches:

| DID Method | History Source | Implementation |
|-----------|---------------|----------------|
| `did:plc:` | `plc.directory/{did}/log/audit` | Already implemented |
| `did:web:` | No standard audit log | Hide handle history section |
| `did:key:` | No audit log | Hide handle history section |

The `fetchPLCAuditLog` should detect DID method and skip gracefully for non-PLC DIDs:

```swift
guard did.hasPrefix("did:plc:") else { return [] }
```

### 4. Per-Account Entryway Storage

Extend `AppAccount` model:

```swift
struct AppAccount: Identifiable, Codable, Hashable {
    let id: UUID
    var handle: String
    var displayName: String
    var did: String?
    var pdsURL: URL?           // Already exists
    var entrywayURL: URL?      // NEW: stores custom entryway
    var lastUsedAt: Date
}
```

The `BlueskySessionService` should use `account.entrywayURL` instead of `entrywayURL` when authenticating for a specific account.

### 5. PLC Directory Fallback

The PLC directory endpoint should use the correct PLC server based on the DID:

```
did:plc:abc123    → https://plc.directory/did:plc:abc123/log/audit
did:plc:xyz789    → https://plc.directory/did:plc:xyz789/log/audit
```

For non-PLC DIDs, the handle history section should be hidden.

### 6. UI Changes

| View | Change |
|------|--------|
| `AddAccountView` | Add optional "PDS Entryway" text field (collapsed by default) |
| `AccountSwitcherSheet` | Show entryway domain next to handle for non-default PDS |
| `AccountRowView` | Small PDS badge when entryway differs from default |
| `InfoView` | Note in Features: "Works with any AT Protocol PDS" |

### 7. Migration for Existing Accounts

Existing accounts that were authenticated through `bsky.social` should continue to work unchanged. The `entrywayURL` defaults to `nil`, which means `bsky.social` is used.

## Implementation Priority

| Priority | Change | Effort | Risk |
|----------|--------|--------|------|
| P1 | Handle domain auto-detection in `authenticationURL` | Low | Low |
| P1 | Store `entrywayURL` in `AppAccount` | Low | Low |
| P2 | Add entryway field to `AddAccountView` | Medium | Low |
| P2 | PLC method guard in `fetchPLCAuditLog` | Low | Low |
| P3 | Show PDS badge in account rows | Low | Low |
| P3 | Update InfoView with multi-PDS claim | Low | Low |

## Testing

| Scenario | Expected behavior |
|----------|------------------|
| User enters `user.bsky.social` | Authenticates against `bsky.social` |
| User enters `user.eurosky.social` | Auto-detects `eurosky.social`, authenticates |
| User enters custom `pds.example.com` | Uses provided PDS for all API calls |
| DID is `did:web:` | API calls work; handle history hidden |
| Account added with custom PDS | Entryway stored in account; survives relaunch |

## Non-Goals

- Cross-PDS federation features (e.g., searching users across PDS instances)
- Multi-PDS account merging
- PDS health monitoring or uptime checks
- Automatic PDS migration
