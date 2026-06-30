# CLAUDE.md

This file provides guidance for Claude Code when working on this project.

## Project Overview

Pesto Clipboard is a macOS menu bar clipboard manager built with SwiftUI. It stores clipboard history (text, images, files) and allows quick access via global hotkey.

## Project Generation (XcodeGen)

The `.xcodeproj` is **generated** from `PestoClipboard/project.yml` using
[XcodeGen](https://github.com/yonaskolb/xcodegen) and is **not** committed to git.
After a fresh clone — and any time `project.yml` changes — regenerate it before building:

```bash
make generate
# or directly:
xcodegen generate --spec PestoClipboard/project.yml
```

Edit `PestoClipboard/project.yml` (targets, build settings, packages, schemes,
entitlements) rather than the generated `project.pbxproj`. The Makefile build/test
targets run `generate` automatically as a prerequisite.

Both `project.pbxproj` and `PestoClipboard/PestoClipboard.entitlements` are generated
and gitignored. Entitlements live under the target's `entitlements.properties` in
`project.yml` — edit them there, not via Xcode's Signing & Capabilities UI (which would
be overwritten on the next `generate`).

## Build Commands

```bash
# Generate the Xcode project first (not needed if using the Makefile targets)
xcodegen generate --spec PestoClipboard/project.yml

# Build the project
xcodebuild -project PestoClipboard/PestoClipboard.xcodeproj -scheme PestoClipboard -configuration Debug build

# Run tests
xcodebuild -project PestoClipboard/PestoClipboard.xcodeproj -scheme PestoClipboard test

# Build for release
xcodebuild -project PestoClipboard/PestoClipboard.xcodeproj -scheme PestoClipboard -configuration Release build
```

## Makefile Commands

The project includes a Makefile with convenient shortcuts:

```bash
make generate       # Generate .xcodeproj from project.yml (XcodeGen)
make build          # Build release version
make build-debug    # Build debug version
make test           # Run tests
make install        # Build and copy to /Applications
make dmg            # Create distributable DMG
make clean          # Remove build artifacts
make bump-version V=0.3.4  # Bump version number
make locales-export # Export translations to markdown
make locales-import # Import translations from markdown
make locales-status # Show translation status
```

## Localization

Translations are managed through markdown files as the source of truth. The workflow uses `scripts/xcstrings.py` to sync between Xcode's `Localizable.xcstrings` and human-editable markdown files in `locales/`.

### File Structure

```
scripts/xcstrings.py              # CLI tool for managing translations
locales/
  de.md                           # German translations
  fr.md                           # French translations
  id.md                           # Indonesian translations
  ...                             # One file per language
PestoClipboard/PestoClipboard/
  Localizable.xcstrings           # Xcode's string catalog (generated)
```

### Workflow

```
xcstrings → export → locales/*.md → edit/review/PR → import → xcstrings
```

### Editing Translations

1. Export current state: `./scripts/xcstrings.py export`
2. Edit the markdown file (e.g., `locales/de.md`)
3. Fill in translations in the table's language column
4. Preview changes: `./scripts/xcstrings.py import --dry-run`
5. Apply changes: `./scripts/xcstrings.py import`
6. Verify build: `make build-debug`

### Adding a New Language

1. Add language code to `LANGUAGES` dict in `scripts/xcstrings.py`
2. Export: `./scripts/xcstrings.py export --lang <code>`
3. Fill in translations in `locales/<code>.md`
4. Import: `./scripts/xcstrings.py import --lang <code>`

### Markdown Format

Each language file uses a table format:

```markdown
| Status | English | German |
|--------|---------|--------|
| ✓ | About | Über |
| ✗ | Settings |  |
| ⚠ | Help | Hilfe |
```

- `✓` = translated
- `✗` = missing (empty target column)
- `⚠` = stale (source changed, needs review)

### CLI Commands

```bash
./scripts/xcstrings.py export                # Export all languages
./scripts/xcstrings.py export --lang de      # Export single language
./scripts/xcstrings.py import                # Import all changes
./scripts/xcstrings.py import --lang de      # Import single language
./scripts/xcstrings.py import --dry-run      # Preview changes
./scripts/xcstrings.py status                # Show translation summary
./scripts/xcstrings.py validate              # Check xcstrings integrity
```

### Supported Languages

ca (Catalan), da (Danish), de (German), en-GB (English UK), es (Spanish), fr (French), hi (Hindi), id (Indonesian), it (Italian), ja (Japanese), ko (Korean), nl (Dutch), ru (Russian), sv (Swedish), zh-Hans (Chinese Simplified)

## Architecture

### Key Components

- **App/AppDelegate.swift** - Sets up global hotkey and initializes StatusBarController
- **App/AppEventBus.swift** - Type-safe Combine-based event bus for inter-component communication
- **Services/ClipboardMonitor.swift** - Polls clipboard for changes every 0.5s
- **Services/ClipboardHistoryManager.swift** - Core Data CRUD operations for clipboard items
- **Services/SettingsManager.swift** - UserDefaults-backed settings (singleton)
- **Views/StatusBar/StatusBarController.swift** - Menu bar icon orchestration
- **Views/StatusBar/FloatingPanel.swift** - NSPanel subclass for the history popup
- **Views/StatusBar/EventMonitorManager.swift** - Global/local event monitoring
- **Views/StatusBar/PreferencesWindowController.swift** - Preferences window lifecycle
- **Views/HistoryPopover/HistoryView.swift** - Main UI for clipboard history list
- **Views/HistoryPopover/HistoryViewModel.swift** - State and business logic for HistoryView
- **Views/HistoryPopover/HistoryKeyboardHandlers.swift** - Keyboard shortcut handling

### Data Flow

1. ClipboardMonitor detects clipboard changes
2. ClipboardHistoryManager saves items to Core Data
3. HistoryView displays items via @ObservedObject binding
4. FloatingPanel shows/hides via global hotkey or menu bar click

### Focus System

The app uses a custom focus system to handle keyboard shortcuts:
- `KeyAcceptingHostingView` (in FloatingPanel.swift) - Custom NSHostingView subclass that accepts first responder
- `FocusField` enum in HistoryView - `.list` (default) or `.search`
- Hotkeys (1-9, arrows, delete) only work when `.list` is focused
- Cmd+F focuses the search field

## Important Patterns

### Event Bus

The app uses a type-safe Combine-based event bus instead of NotificationCenter:

```swift
// Send events
AppEventBus.shared.showHistoryPanel()
AppEventBus.shared.hideHistoryPanel()
AppEventBus.shared.deleteSelectedItem()

// Subscribe to events
AppEventBus.shared.publisher(for: .showHistoryPanel)
    .sink { /* handle event */ }
    .store(in: &cancellables)
```

### Settings Persistence

Settings in `SettingsManager` use `@Published` with `didSet` to persist to UserDefaults:
- `plainTextMode` - Paste as plain text
- `isPaused` - Pause clipboard monitoring
- `pasteAutomatically` - Auto-paste on selection

### Panel Behavior

- `FloatingPanel` is a borderless, non-activating NSPanel
- Stays visible across spaces
- Returns focus to previous app after paste
- Position persists via UserDefaults

## Code Style

- SwiftUI for all views
- No storyboards or XIBs
- Core Data for persistence (programmatic model)
- Combine for reactive bindings
- KeyboardShortcuts package for global hotkey

## Common Tasks

### Adding a new setting

1. Add `@Published var` to SettingsManager with UserDefaults didSet
2. Initialize from UserDefaults in `init()`
3. Add UI in PreferencesView if needed

### Adding a new hotkey

1. Add `.onKeyPress` handler in `HistoryKeyboardHandlers.swift`
2. Check `isSearchFocused` if hotkey should be disabled during search
3. Return `.handled` or `.ignored` appropriately

## Testing

Tests are in `PestoClipboardTests/`. Run with xcodebuild test command above.
