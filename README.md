# mado

A productivity app for macOS and iOS that unifies Google Calendar, Google Tasks, and notes into a single workspace.

## Features

- **Calendar** — Daily, weekly, and monthly views synced with Google Calendar
- **Tasks** — Full Google Tasks integration with natural language date parsing, subtasks, labels, and priorities
- **Notes** — Markdown editor with daily notes and a compact today-calendar sidebar
- **Menu bar** — Quick-glance popover showing upcoming events and tasks (macOS)
- **Quick add** — Global shortcut to add tasks from anywhere (macOS)
- **Invites** — Dedicated panel for pending calendar invitations
- **Search** — Unified search across events and tasks
- **Widget** — iOS widgets for today's events, tasks, next meeting, and overdue items
- **Sync** — Firestore-backed cross-device sync

## Architecture

| Target | Platform | Bundle ID |
|---|---|---|
| `Mado` | macOS 14+ | `io.mado.app` |
| `MadoiOS` | iOS 17+ | `io.mado.mobile` |
| `MadoWidgetExtension` | iOS 17+ | `io.mado.mobile.widget` |

- **Swift 5.9** / **SwiftUI** / **SwiftData**
- Project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`
- Dependencies managed via Swift Package Manager:
  - [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) — OAuth authentication
  - [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Global hotkeys (macOS)

## Project Structure

```
Mado/
  Core/
    Authentication/     # Google OAuth sign-in, token management
    Networking/         # APIClient, Google Calendar/Tasks/Gmail services
    Persistence/        # SwiftData models (CalendarEvent, MadoTask, Project, etc.)
    Sync/               # SyncEngine + Firestore REST sync
  Components/           # Reusable UI (chips, badges, empty states, undo toast)
  Design/               # Colors and theme constants
  Features/
    Auth/               # Login flow
    Calendar/           # Calendar views (daily, weekly, monthly)
    MainWindow/         # Root window layout
    Memos/              # Markdown notes editor
    MenuBar/            # Menu bar popover (macOS)
    Planner/            # Main planner view, command bar, task/invite panels
    Search/             # Search overlay
    Settings/           # Settings and calendar selection
    Todo/               # Task list, detail, form, subtasks
MadoiOS/                # iOS-specific views (tabs, sheets)
MadoWidget/             # WidgetKit extensions
```

## Setup

### Prerequisites

- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (optional — `.xcodeproj` is committed)
- Google Cloud project with Calendar, Tasks, and Gmail APIs enabled

### Google OAuth Credentials

Place these files in the project root (they are git-ignored):

- `client_<id>.apps.googleusercontent.com.plist` — iOS OAuth client
- `client_secret_<id>.apps.googleusercontent.com.json` — Web/desktop OAuth client

### Build & Run

```bash
# macOS — build and install to /Applications
./install.sh

# Or open in Xcode
open Mado.xcodeproj
```

### Regenerate Xcode Project (if needed)

```bash
xcodegen generate
```

## Keyboard Shortcuts (macOS)

| Shortcut | Action |
|---|---|
| `Cmd+Y` | Toggle menu bar popover |
| `Cmd+J` | Join next meeting |
| `Cmd+0` | Quick add task |
| `Cmd+Shift+P` | Open main window |
| `Cmd+K` | Command bar |
| `Cmd+F` | Search |
| `Cmd+D` | Today's note |
| `Cmd+Shift+N` | Toggle notes panel |
| `M` / `W` / `D` | Month / Week / Day view |
| `T` | Go to today |
| `J` / `K` | Navigate forward / back |
| `[` / `]` | Toggle side panels |
| `\` | Toggle notes mode |

## License

Private — all rights reserved.
