# AI Context Index - ABS Platform

## Project Overview

**Name**: ABS Platform (AI-Bootstrap System Platform)
**Type**: Flutter Desktop Application
**Purpose**: Project management tool with integrated AI assistance
**Current Version**: 0.1.0-alpha
**Status**: Active Development - Core features functional

## Quick Start for AI Assistants

**Current Focus**: App is now fully functional - all core features working

**Recent Changes**: 
- Fixed model selector parameter order bug ✅
- Implemented clickable file viewer ✅
- Added session creation functionality ✅
- Fixed widget tests ✅
- Built fresh Windows release ✅

## Key Files

### Core Application
- `lib/main.dart` - App entry point, Hive initialization
- `lib/screens/project_detail_screen.dart` - Project view with FAB
- `lib/screens/ai_chat_screen.dart` - AI chat interface (HAS BUG)
- `lib/screens/settings_screen.dart` - API key management

### State Management
- `lib/providers/ai_provider.dart` - AI configuration, model selection
- `lib/providers/project_provider.dart` - Project CRUD operations

### Services
- `lib/services/ai_service.dart` - Multi-provider AI API client
- `lib/services/file_service.dart` - File I/O operations

## Architecture

### State Management: Riverpod
- Pattern: Provider pattern with StateProvider
- Key providers: selectedAIProviderProvider, selectedModelProvider, aiKeysProvider

### Storage: Hive
- Boxes: ai_keys, projects
- Local NoSQL database

### AI Integration
**Supported Providers**:
1. OpenAI - GPT-4o, GPT-4o-mini (default), GPT-3.5-turbo
2. Anthropic - Claude-3.5-Sonnet, Claude-3-Opus, Claude-3-Haiku
3. Google Gemini - Gemini-2.0-Flash (Free), Gemini-1.5-Pro

## Current State

### Working Features ✅
- Project management (create, list, delete)
- AI chat interface with conversation history
- Settings with API key management
- FAB for easy AI chat access
- Provider and model selection UI
- **File viewer with copy functionality**
- **Session creation and tracking**
- **SESSION_NOTES.md auto-update**

### Known Issues ⚠️
1. **Old Project Data** (NON-BLOCKING) - Null subtype error on old data
2. **Debug Logging** - Still present in ai_chat_screen.dart (cleanup needed)

### Missing Features ⏳
- File auto-refresh after AI updates
- Markdown rendering in file viewer
- Session detail view
- Session end functionality

## Common Tasks

### Debug Logging
```dart
print('DEBUG: variable=$variable');
```

### Hot Reload
Press `r` in Flutter terminal

### Analyze Code
```bash
flutter analyze lib/screens/filename.dart
```

## Recent Decisions

1. FAB placement: Bottom right (Material Design standard)
2. Keep both FAB and app bar icon for flexibility
3. Model selection: Per-provider, not per-project
4. Debug first: Add logging before fixing

---

**Last Updated**: December 5, 2025
**Current Priority**: Fix model="test" bug blocking AI functionality
