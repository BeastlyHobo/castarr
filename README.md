<div align="center">
  <img src="Castarr.png" alt="Castarr" width="200"/>
</div>

# Castarr

An iOS app for Plex power‑users to browse active sessions on your Plex Media Server and dive into rich, IMDb‑powered cast details — rebuilt with a refreshed UI, faster networking, and quality‑of‑life improvements.

## Features

- **Plex OAuth Login**: Secure authentication via Plex.tv with MFA support
- **Demo Mode**: Built-in demo account for app reviewers and demos
- **Active Sessions**: Real‑time view of who’s watching what on your server
- **Cast + Crew**: IMDb integration for actor bios, photos, filmography
- **Movie Details**: Technical info, ratings, and artwork
- **Server Insights**: Server capabilities, activities, and sessions views
- **HTTPS/HTTP Fallback**: Better connectivity for self‑hosted, external, or self‑signed setups

## Setup

1. Open Settings and enter your Plex Media Server IP (port `32400` is used automatically)
2. Tap "Login with Plex" to authenticate via Plex.tv
3. Browse active sessions and tap a title to view cast details

No API keys required.

## Demo Mode

For app reviewers and demos: tap "App Review? Use Demo Account" on the login screen to explore without a Plex server.

## Requirements

- iOS 16.6+
- Xcode 15+
- Swift 5.0+
- Plex Media Server with network access
- Valid Plex account

## Building

Open `Castarr.xcodeproj` in Xcode and build. Select the `Castarr` scheme (or the app target) and run.

```bash
# Simulator
xcodebuild -project "Castarr.xcodeproj" -scheme "Castarr" \
  -destination 'generic/platform=iOS Simulator,name=iPhone 16' build

# Device
xcodebuild -project "Castarr.xcodeproj" -scheme "Castarr" \
  -destination 'generic/platform=iOS' build
```

## API Endpoints

### Plex
- `POST https://plex.tv/api/v2/pins` - OAuth PIN generation
- `GET https://plex.tv/api/v2/pins/{pinId}` - OAuth polling
- `GET http://{server}:32400/?X-Plex-Token={token}` - Server capabilities
- `GET http://{server}:32400/status/sessions?X-Plex-Token={token}` - Active sessions
- `GET http://{server}:32400/library/metadata/{id}?X-Plex-Token={token}` - Movie metadata

### IMDb (api.imdbapi.dev)
- `GET /names/{nameId}` - Actor information
- `GET /names/{nameId}/filmography` - Actor filmography
- `GET /titles/{titleId}` - Movie details
- `GET /titles/{titleId}/credits` - Movie cast and crew
- `GET /search/titles` - Movie search

No API key required for IMDb — uses free public API.

## Attribution

Castarr is based on and inspired by the original RoleCall project — credit to the original creator for the foundational work and ideas. This fork includes a new brand, UI/UX refinements, network resiliency, and expanded views.

## License

See `LICENSE`.
