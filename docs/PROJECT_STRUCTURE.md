# Castarr Project Structure

## Overview
- `CastarrApp.swift`: App entry point; launches `ContentView`.
- `ContentView.swift`: Chooses between `MainView` (logged in) and `LoginView`; presents settings sheet.

## Views (`Castarr/Views`)
- `MainView.swift`: Core dashboard displaying now playing details, gradients, and metadata expansion.
- `LoginView.swift`: Authentication screen with Plex login and demo flow.
- `SettingsView.swift`: Server configuration form and navigation to server detail views.
- `ActivitiesView.swift`, `SessionsView.swift`, `ServerCapabilitiesView.swift`: Plex server information screens.
- `MovieDetailView.swift`, `ActorDetailView.swift`: Detail components for media and cast.

## Services (`Castarr/Services`)
- `PlexService.swift`: Central data/service layer managing authentication, sessions, and API calls.
- `DemoService.swift`: Demo account helpers.
- `IMDbService.swift`: Fetches supplemental ratings metadata.

## Models (`Castarr/Models`)
- `PlexModels.swift`: Codable representations of Plex API responses and helper types.

## Resources
- `Assets.xcassets`: App icons, accent color, and other asset catalogs.
- `Info.plist`: App configuration.

## Tests
- `CastarrTests`: Unit test targets.
- `CastarrUITests`: UI test targets and launch tests.

## Theming Notes
- Global colors, typography, and reusable styles live in `Castarr/Views/Theme.swift`.
- Named color assets (`Castarr*.colorset`) back the theme for easy palette tweaks.
- Accent usage: primary buttons/highlights use `Theme.Colors.primaryAccent` (darker orange) and secondary elements use `Theme.Colors.secondaryAccent` (deep blue-teal).
