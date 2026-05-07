# Bluesky Moderation

A polished native iOS app for managing multiple Bluesky accounts and browsing your lists — including moderation lists.

## Features

- **Multi-Account Support** — Add and manage multiple Bluesky accounts with app-specific passwords
- **Secure Storage** — All credentials stored in the iOS Keychain, never in plain text
- **Account Switching** — Tap to switch between accounts instantly
- **List Browser** — View all your curation and moderation lists with filtering and search
- **List Detail** — Tap any list to see its members
- **Dark Mode** — Full support for iOS Dark Mode
- **Accessibility** — VoiceOver labels, Dynamic Type support, and proper contrast

## Architecture

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| State | `@Observable` (Observation framework) |
| Networking | URLSession + async/await |
| Persistence | SwiftData (account metadata) |
| Secrets | Keychain (app passwords & tokens) |

## Project Setup

1. Open **Xcode 15+**
2. Create a new **iOS App** project:
   - **Name**: `BlueskyModeration`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deployments**: iOS 17.0
3. In Finder, drag all folders from this `BlueskyModeration/` directory into your Xcode project
4. Ensure **"Copy items if needed"** is checked and **"Create groups"** is selected
5. Build and run (`⌘+R`)

## File Structure

```
BlueskyModeration/
├── App/
│   ├── BlueskyModerationApp.swift      # App entry point with SwiftData container
│   └── ContentView.swift               # TabView root (Lists, Accounts, Settings)
├── Features/
│   ├── Accounts/
│   │   ├── Models/
│   │   │   ├── BlueskyAccount.swift    # SwiftData @Model
│   │   │   └── AccountSession.swift    # In-memory auth session
│   │   ├── Views/
│   │   │   ├── AccountListView.swift   # Account management screen
│   │   │   ├── AddAccountView.swift    # Sheet to add new account
│   │   │   └── AccountRowView.swift    # Individual account row
│   │   └── ViewModels/
│   │       └── AccountViewModel.swift  # Add, switch, remove accounts
│   ├── Lists/
│   │   ├── Models/
│   │   │   ├── BlueskyList.swift       # List model with purpose
│   │   │   └── ListItem.swift          # List member model
│   │   ├── Views/
│   │   │   ├── ListOverviewView.swift  # All lists with filtering
│   │   │   ├── ListRowView.swift       # Individual list row
│   │   │   └── ListDetailView.swift    # List members screen
│   │   └── ViewModels/
│   │       └── ListViewModel.swift     # Fetch and filter lists
│   └── Shared/
│       └── Components/
│           ├── EmptyStateView.swift    # Illustrated empty states
│           ├── LoadingStateView.swift  # Skeleton loaders
│           └── ErrorBanner.swift       # Inline error messages
├── Services/
│   ├── BlueskyAPI/
│   │   ├── BlueskyAPIService.swift     # AT Protocol API client
│   │   ├── ATProtoModels.swift         # Codable API responses
│   │   └── ATProtoError.swift          # Typed errors
│   └── Keychain/
│       └── KeychainService.swift       # Secure credential storage
└── Resources/
    └── Assets.xcassets/
```

## AT Protocol APIs Used

- `com.atproto.server.createSession` — Authenticate
- `com.atproto.identity.resolveHandle` — Resolve handle → DID
- `app.bsky.graph.getLists` — Fetch all lists
- `app.bsky.graph.getList` — Fetch list with members
- `plc.directory/{did}` — DID document resolution

## Security Notes

- App passwords are stored exclusively in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Access tokens are cached in Keychain between sessions
- Account metadata (handle, DID, PDS endpoint) is stored in SwiftData
- No analytics, tracking, or third-party SDKs
