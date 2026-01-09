# CLAUDE.md

This file provides guidance for Claude Code when working on this project.

## Project Overview

Pesto Clipboard is a macOS menu bar clipboard manager built with SwiftUI. It stores clipboard history (text, images, files) and allows quick access via global hotkey.

## Build Commands

```bash
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
make build          # Build release version
make build-debug    # Build debug version
make test           # Run tests
make install        # Build and copy to /Applications
make dmg            # Create distributable DMG
make clean          # Remove build artifacts
make bump-version V=0.3.4  # Bump version number
```

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
