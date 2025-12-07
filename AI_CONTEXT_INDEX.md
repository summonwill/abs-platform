# AI Context Index - ABS Platform

## Project Overview

**Name**: ABS Platform (AI-Bootstrap System Platform)
**Type**: Flutter Desktop Application (Windows)
**Purpose**: Project management tool with integrated AI assistance and file operations
**Current Version**: 0.2.0-alpha
**Status**: Active Development

## Quick Start for New AI Chat Sessions

### Current Focus: Python Script Execution

**Next feature to implement**: Python script execution for Excel/VBA operations

**What's working:**
- AI file operations (CREATE, UPDATE, DELETE)
- Session auto-stop (heartbeat mechanism)
- File editor in separate windows
- Directory navigation and file management

### Key Architecture Points

1. **Multi-Window = Separate Processes**: Each `desktop_multi_window` sub-window is a separate OS process
2. **No Shared Memory**: Hive/providers only in main window, use file-based sync
3. **Heartbeat for Crash Detection**: Chat window writes `.abs_session_heartbeat` every 1s
4. **File-Based Communication**: `.abs_chat_history.json` syncs state between windows

## Key Files to Know

### Core Application
| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point, Hive init, window routing |
| `lib/screens/project_detail_screen.dart` | Project view, file explorer, heartbeat checker |
| `lib/screens/ai_chat_screen.dart` | AI chat, file operations, heartbeat writer |
| `lib/windows/ai_chat_window.dart` | Separate window wrapper, "Close & Save" button |
| `lib/windows/file_editor_window.dart` | Separate window file editor (re_editor) |

### Services
| File | Purpose |
|------|---------|
| `lib/services/ai_service.dart` | Multi-provider AI client (OpenAI, Anthropic, Gemini) |
| `lib/services/file_service.dart` | File I/O, Windows-native delete commands |

### State Management
| File | Purpose |
|------|---------|
| `lib/providers/ai_provider.dart` | AI config, model selection, API keys |
| `lib/providers/project_provider.dart` | Project CRUD, session management |

## AI File Operation Format

```
=== CREATE: path/to/file.txt ===
content here
=== END ===

=== UPDATE: existing/file.md ===
new content
=== END ===

=== DELETE: path/to/file.txt ===
=== DELETE: folder/ ===  (trailing slash for folders)
```

## Session/Heartbeat System

### How It Works
1. Chat window writes `.abs_session_heartbeat` file every **500ms** with timestamp
2. Main window checks heartbeat file every **1 second**
3. If heartbeat > **1 second** old → window crashed → auto-complete session
4. "Close & Save" button: stops session properly, deletes heartbeat
5. **Pre-session check**: Before opening/creating sessions, checks for active heartbeat
6. **Accumulated duration**: Sessions track total time across multiple open/close cycles

### Runtime Files (in project directory)
- `.abs_session_heartbeat` - Timestamp file while chat window is open
- `.abs_chat_history.json` - Project state for main window sync

## Completed Features ✅

- Project management (create, list, delete)
- AI chat with OpenAI, Anthropic, Gemini
- AI file CREATE/UPDATE/DELETE operations
- Subfolder support for all operations
- Live file updates (FileSystemWatcher)
- Directory navigation with breadcrumbs
- User create/delete files and folders
- File editor in separate floating windows (re_editor)
- Session auto-stop on window close (heartbeat)
- OneDrive compatibility (Windows rmdir command)
- **Session timing fixes** (accumulated duration, negative duration protection)
- **Fast heartbeat detection** (500ms write, 1s stale, ~2s max detection)
- **Pre-session heartbeat check** (prevents opening during active session)

## Next Features (TODO)

1. **Python Script Execution** ← NEXT
   - Detect Python, run scripts in project dir
   - `=== EXECUTE: script.py ===` format
   - Capture and display output

2. **Excel/VBA via Python**
   - openpyxl for Excel read/write
   - xlwings/win32com for VBA

3. **File Editor Enhancements**
   - Syntax highlighting
   - Line numbers
   - Code folding

## Known Bugs (Non-Blocking)

1. Old project data → Null subtype error
2. MissingPluginException → macOS method on Windows

## Technical Constraints

| Issue | Solution |
|-------|----------|
| OneDrive file locking | Use `rmdir /s /q` instead of Dart delete |
| Separate window no Hive | Use `isInSeparateWindow` flag, file-based sync |
| Window X button kills process | Heartbeat mechanism for detection |
| WebView crashes in sub-windows | Use native Flutter widgets (re_editor) |

---

**Last Updated**: December 7, 2025
**See Also**: SESSION_NOTES.md, TODO.md
