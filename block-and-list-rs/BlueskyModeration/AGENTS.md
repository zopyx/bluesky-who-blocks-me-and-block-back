# BlueskyModeration — Agent Guide

## Project Overview

Native iOS app (iOS 17+) for managing multiple Bluesky accounts and browsing moderation/curation lists. Built with SwiftUI, SwiftData, and URLSession.

- **Language**: Swift 5
- **UI Framework**: SwiftUI + Observation (`@Observable`)
- **Persistence**: SwiftData (account metadata), Keychain (credentials)
- **Networking**: URLSession + async/await (AT Protocol)
- **Testing**: Swift Testing (modern `@Suite` / `@Test` macros)
- **Project Gen**: XcodeGen (`project.yml`)

## Architecture

```
App/                 → Entry point, root views
Features/
  Accounts/          → Account management (MVVM)
  Lists/             → List browsing (MVVM)
  Shared/            → Reusable SwiftUI components
Services/
  BlueskyAPI/        → AT Protocol API client (actor)
  Keychain/          → Secure credential storage (actor)
Tests/               → Unit tests
```

### Dependency Injection

Services are exposed via protocols for testability:

- `BlueskyAPIProtocol` — implemented by `BlueskyAPIService`
- `KeychainProtocol` — implemented by `KeychainService`

`AccountViewModel` accepts these via `init(apiService:keychain:)` with `.shared` defaults. Always inject mocks in tests.

## Coding Conventions

### Swift Style
- Use `async/await` for all asynchronous work. No completion handlers.
- Actors for thread-safe services (`BlueskyAPIService`, `KeychainService`).
- `@Observable` classes for ViewModels, not `ObservableObject`.
- SwiftData `@Model` classes for persistence.
- Use `Sendable` conformance on models and protocols where appropriate.

### Naming
- Views: `*View.swift`
- ViewModels: `*ViewModel.swift`
- Models: `*Model.swift` or descriptive (`BlueskyAccount.swift`)
- Services: `*Service.swift`
- Protocols: `*Protocol`

### Error Handling
- Network errors: use typed `ATProtoError` enum.
- Keychain errors: use typed `KeychainError` enum.
- User-facing messages: set `ViewModel.errorMessage` (localized string).
- Never expose raw `Error.localizedDescription` to UI without context.

### Security
- App passwords → Keychain only (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- Access tokens → Keychain only.
- Never log passwords or tokens.
- Never store credentials in `UserDefaults` or SwiftData.

### UI Patterns
- Use `NavigationStack`, `Form`, `List` where appropriate.
- Support Dark Mode and Dynamic Type out of the box.
- Add `accessibilityLabel` to custom buttons and non-obvious icons.
- Use `#Preview` for all views.

## Build & Test

### Generate Project
```bash
xcodegen generate
```

### Build
```bash
make build
# or
xcodebuild -project BlueskyModeration.xcodeproj -scheme BlueskyModeration -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build
```

### Run Tests
```bash
make test
# or
xcodebuild -project BlueskyModeration.xcodeproj -scheme BlueskyModeration -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test
```

## Quality Gates

Before any code change is considered complete, **all** of the following must pass:

1. **Build Clean**
   - `xcodebuild build` succeeds with **zero errors** and **zero warnings**.

2. **Tests Pass**
   - All tests in `Tests/` pass.
   - New features must include tests covering the happy path and at least one failure path.
   - Bug fixes must include a regression test.

3. **Testability**
   - New services must define a `*Protocol` and be injected into ViewModels.
   - No hardcoded singleton access in testable logic (use init defaults instead).

4. **SwiftData In-Memory Tests**
   - Tests using SwiftData must use `ModelConfiguration(isStoredInMemoryOnly: true)`.
   - Never mock `ModelContext` via subclassing.

5. **No Credential Leaks**
   - No passwords or tokens in logs, print statements, or test assertions.
   - Keychain is the only allowed credential store.

6. **Accessibility**
   - Custom buttons and icon-only controls have `accessibilityLabel`.
   - Views support Dynamic Type (avoid fixed frame sizes where possible).

7. **Project Consistency**
   - If files are added/removed/moved, regenerate `project.yml` and run `xcodegen generate`.
   - New source files belong under `App/`, `Features/`, `Services/`, or `Tests/`.
