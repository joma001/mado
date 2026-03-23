# Mado — Claude Code Instructions

## Project Overview

Mado is a personal productivity app (macOS + iOS) that integrates Google Calendar, Google Tasks, and markdown notes. Built with Swift 5.9, SwiftUI, and SwiftData.

## Build & Run

```bash
# Regenerate Xcode project from project.yml
xcodegen generate

# Build and install macOS app
./install.sh

# Or build via xcodebuild
xcodebuild -project Mado.xcodeproj -scheme Mado -configuration Debug build
xcodebuild -project Mado.xcodeproj -scheme MadoiOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Key Architecture Decisions

- **XcodeGen**: The Xcode project is generated from `project.yml`. Edit `project.yml` for target/dependency changes, then run `xcodegen generate`.
- **Shared code**: `Mado/` contains code shared between macOS and iOS. macOS-only files are excluded from the iOS target via `project.yml` excludes list.
- **iOS-specific views**: All in `MadoiOS/`, prefixed with `iOS` (e.g., `iOSCalendarTab.swift`).
- **No Firebase SDK**: Firestore sync uses the REST API directly (`FirestoreClient.swift`), not the Firebase iOS SDK.
- **Google APIs**: Calendar, Tasks, and Gmail accessed via REST through `APIClient` with automatic token refresh and retry logic.
- **SwiftData**: All persistence uses SwiftData models in `Core/Persistence/Models/`.
- **Singletons**: `DataController.shared`, `AuthenticationManager.shared`, `SyncEngine.shared`, `MenuBarViewModel.shared` are app-wide singletons.

## Code Conventions

- Use `#if os(macOS)` / `#if os(iOS)` for platform-specific code in shared files
- ViewModels are `@Observable` classes
- Networking methods are `async throws` on the `APIClient` actor
- Colors via `MadoColors`, layout constants via `MadoTheme`
- Keyboard shortcuts: global ones in `MadoAppDelegate`, view-local ones via hidden `Button` with `.keyboardShortcut`

## Secrets (git-ignored)

These files must exist in the project root but are NOT in the repo:

- `client_102145055155-a3jdtpgj1ig53a3vqoe0qf5v170qruq7.apps.googleusercontent.com.plist`
- `client_secret_102145055155-mbkvnmmf7885kajj5p0nhqo7ias77gj9.apps.googleusercontent.com.json`

Firebase project ID: `mado-ba266` (hardcoded in `FirestoreConfig.swift`)

## Common Tasks

- **Add a new SwiftData model**: Create in `Mado/Core/Persistence/Models/`, register in `DataController`
- **Add a new feature view**: Create under `Mado/Features/<FeatureName>/` for shared, or `MadoiOS/` for iOS-only
- **Add a dependency**: Update `packages` and target `dependencies` in `project.yml`, then `xcodegen generate`
- **Add a new widget**: Create in `MadoWidget/`, update `MadoWidgetBundle.swift`
