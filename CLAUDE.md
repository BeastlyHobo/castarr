# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Castarr is a **pure SwiftUI iOS app** (iOS 16.6+, Xcode 15+, Swift 5.0+) that acts as a companion for Plex Media Server. It has no external Swift package dependencies — only Foundation, SwiftUI, and Combine.

## Build & Test Commands

```bash
# Open in Xcode (preferred for development)
open Castarr.xcodeproj

# Build for simulator (CLI)
xcodebuild -project "Castarr.xcodeproj" -scheme "Castarr" \
  -destination 'generic/platform=iOS Simulator,name=iPhone 16' build

# Build for device (CLI)
xcodebuild -project "Castarr.xcodeproj" -scheme "Castarr" \
  -destination 'generic/platform=iOS' build

# Run all tests
xcodebuild -project "Castarr.xcodeproj" -scheme "Castarr" \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class
xcodebuild -project "Castarr.xcodeproj" -scheme "Castarr" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CastarrTests/CastarrTests test
```

There is no linter or formatter configured; standard Xcode formatting applies.

## Architecture

### Data Flow

`PlexService` (singleton, `@MainActor`) is the single source of truth. It owns all `@Published` state (current session, server capabilities, auth status). Views observe it via `@EnvironmentObject`. `IMDbService` is a separate singleton for enrichment data only — it is not injected via environment; views call it directly as a shared instance.

```
ContentView
  ├── LoginView           ← reads/writes PlexService
  └── MainView            ← primary dashboard, owns most UI state
        ├── SessionsView
        ├── ActivitiesView
        ├── ServerCapabilitiesView
        ├── MovieDetailView
        └── ActorDetailView
```

`ContentView` toggles between `LoginView` and `MainView` based on `PlexService.isLoggedIn`.

### Service Layer

**`PlexService.swift`** (~1,600 lines) handles:
- Plex OAuth flow: PIN generation → browser redirect → polling loop until token received
- Session/activity/capability fetching via XML parsed into `Codable` structs
- UserDefaults persistence of `PlexSettings` (server IP, token, account info)
- Custom `URLSession` with 15s timeout and a `PlexURLSessionDelegate` that accepts self-signed certs (needed for self-hosted Plex)
- Demo mode: detected by email `castarrdemo@yahoo.com`, delegates to `DemoService`

**`IMDbService.swift`** (~700 lines) handles:
- REST calls to `api.imdbapi.dev` (no API key required)
- In-memory cache with 1-hour TTL, capped at 50 entries

**`DemoService.swift`** provides hard-coded mock data (Night of the Living Dead, IMDb ID `tt0063350`) for app reviewers without a Plex server.

### Models

All Codable structs live in `PlexModels.swift`. Key patterns:
- Plex XML responses use attribute-based decoding (custom `CodingKeys` mapping XML attributes)
- IMDb IDs are extracted from Plex `guid` fields that may look like `imdb://tt1234567` or `com.plexapp.agents.imdb://tt1234567`
- Rating values coerce strings to doubles in custom `init(from:)` implementations

### Theming

All colors, typography constants, and reusable `ButtonStyle`/`ViewModifier` implementations live in `Theme.swift`. Named color assets in `Assets.xcassets` back the palette for light/dark mode. Use `Theme.Colors.*` for colors and `.themeCard()` / `.themeTag()` modifiers for consistent card/badge styling.

## Key Conventions

- **`@MainActor` on `PlexService`**: All mutations go through this service on the main actor. Don't bypass it by writing directly to UserDefaults or calling Plex/IMDb endpoints outside the service layer.
- **XML parsing**: Plex API returns XML, not JSON. Responses are decoded via `XMLDecoder` (or manual attribute parsing) into the `Codable` structs in `PlexModels.swift`.
- **HTTP allowed**: `Info.plist` sets `NSAllowsArbitraryLoads = true` intentionally — Plex servers are often self-hosted HTTP with self-signed certs.
- **Demo mode guard**: Before any real network call in `PlexService`, check `isDemoMode` and delegate to `DemoService` if true.
- **IMDb cache**: Always go through `IMDbService.shared` (never construct a new instance); the shared instance holds the cache.
