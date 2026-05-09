# Rulyx — Project Guide for AI Agents

## Project Overview
iOS SwiftUI app for Bluesky moderation (lists, bulk operations, profile inspection, followers/following management). Targets iOS 17+, uses xcodegen for project generation.

## Build & Test
```bash
xcodegen generate
xcodebuild -project BlueskyModeration.xcodeproj -scheme BlueskyModeration -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project BlueskyModeration.xcodeproj -scheme BlueskyModeration -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO
```

## Key Architecture
- **Services**: `BlueskyRequestExecutor`, `BlueskySessionService`, `BlueskyListService`, `BlueskyProfileService`
- **Stores**: `ModerationWorkspaceStore`, `WorkspacePreferencesStore`, `ModerationAuditStore`, `ActionQueueStore`
- **Controllers**: `ListMembersController`, `ListImportController`, `ListDiffController`, `ListBatchController`
- **Views**: SwiftUI with `@EnvironmentObject` injection via `AppDependencies`
- **Navigation**: `NavigationStack` with `NavigationLink` and `.navigationDestination`
- **DI**: All dependencies created in `AppDependencies` and injected as environment objects

## Task Documentation Requirement
Every completed task MUST include an accurate description rendered as a table:

| Area | Change | Impact |
|------|--------|--------|
| Files modified | List of files | What was done and why |

## Coding Conventions
- Swift 6 with strict concurrency (`@MainActor` where needed)
- `Sendable` conformance on model types
- AppError for normalized error handling
- Logger via `AppLogger` (search, persistence, moderation, performance categories)
- Project generated with `xcodegen` from `project.yml` — never edit `.pbxproj` directly
- Views in `Sources/Features/Lists/`, `Sources/Features/Profile/`, `Sources/Features/Accounts/`
- Services in `Sources/Domain/Services/`
- Models in `Sources/Domain/Models/`
