# AI Context Index - ABS Platform

## Project Overview

**Name**: ABS Platform (AI-Bootstrap System Platform)
**Type**: Flutter Desktop Application
**Purpose**: Project management tool with integrated AI assistance and file operations
**Current Version**: 0.2.0-alpha
**Status**: Active Development - File management features complete

## Quick Start for AI Assistants

**Current Focus**: Python script execution and Excel/VBA operations

**Recent Changes (December 6, 2025)**:
- AI file operations: CREATE, UPDATE, DELETE files and folders ✅
- Subfolder support for all file operations ✅
- Live file updates with FileSystemWatcher ✅
- Directory navigation with tree view and breadcrumbs ✅
- User create/delete files and folders via UI ✅
- OneDrive compatibility fix (rmdir command) ✅
- Separate window Hive error fix ✅

## Key Files

### Core Application
- `lib/main.dart` - App entry point, Hive initialization, window routing
- `lib/screens/project_detail_screen.dart` - Project view with file explorer, FAB
- `lib/screens/ai_chat_screen.dart` - AI chat interface with file operations
- `lib/screens/settings_screen.dart` - API key management
- `lib/windows/file_editor_window.dart` - Separate window file editor (re_editor)
- `lib/windows/ai_chat_window.dart` - Separate window AI chat

### State Management
- `lib/providers/ai_provider.dart` - AI configuration, model selection
- `lib/providers/project_provider.dart` - Project CRUD operations

### Services
- `lib/services/ai_service.dart` - Multi-provider AI API client with file operation prompts
- `lib/services/file_service.dart` - File I/O operations (Windows-native deletion)

## Architecture

### State Management: Riverpod
- Pattern: Provider pattern with StateProvider
- Key providers: selectedAIProviderProvider, selectedModelProvider, aiKeysProvider

### Storage: Hive
- Boxes: ai_keys, projects
- Note: Only accessible from main window process

### Multi-Window: desktop_multi_window
- Creates separate OS processes for each window
- Windows communicate via window arguments (JSON)
- Hive not available in sub-windows

### AI File Operation Format
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

## Current State

### Working Features ✅
- Project management (create, list, delete)
- AI chat with multi-provider support (OpenAI, Anthropic, Gemini)
- File editor in separate floating windows
- **AI file CREATE/UPDATE/DELETE operations**
- **Subfolder support for all operations**
- **Live file updates (FileSystemWatcher)**
- **Directory navigation with breadcrumbs**
- **User create/delete files and folders**
- **OneDrive compatibility**

### Known Issues ⚠️
1. **Old Project Data** (NON-BLOCKING) - Null subtype error
2. **MissingPluginException** (NON-BLOCKING) - macOS method on Windows

### Pending Features ⏳
- Syntax highlighting in file editor
- Python script execution
- Excel/VBA operations

## Technical Constraints

**OneDrive File Locking**: Use Windows rmdir /s /q command instead of Dart Directory.delete()

**Separate Window Hive**: Skip provider refresh in sub-windows using isInSeparateWindow flag

---

**Last Updated**: December 6, 2025
