# ABS Platform (AI-Bootstrap System Platform)

A Flutter desktop application for AI-assisted project management with integrated file operations.

## Features

### Core Features
- **Project Management** - Create, manage, and organize projects with governance files
- **AI Chat Integration** - Multi-provider support (OpenAI, Anthropic, Google Gemini)
- **Separate Floating Windows** - AI chat and file editor in independent windows

### File Management
- **AI File Operations** - AI can CREATE, UPDATE, and DELETE files and folders
- **Subfolder Support** - Full nested directory operations
- **Live File Updates** - Files auto-refresh when modified by AI or externally
- **Directory Navigation** - Tree view with breadcrumbs, expand/collapse folders
- **User CRUD Operations** - Create, rename, delete files and folders via UI
- **Context Menus** - Right-click support for file operations

### AI Capabilities
- **Multi-Provider Support**: OpenAI (GPT-4o, GPT-4o-mini), Anthropic (Claude), Google Gemini
- **Project Context Awareness**: AI reads governance files for project understanding
- **File Tree Context**: AI sees complete project structure
- **Conversation History**: Persistent chat sessions

## Getting Started

### Prerequisites
- Flutter SDK (3.10.3+)
- Windows 10/11 (primary target)
- API keys for AI providers (OpenAI, Anthropic, or Gemini)

### Installation
```bash
git clone https://github.com/summonwill/abs-platform.git
cd abs-platform
flutter pub get
flutter run -d windows
```

### Configuration
1. Launch the app
2. Go to Settings (gear icon)
3. Enter your API keys for desired AI providers
4. Create a new project or open existing

## Architecture

- **Framework**: Flutter 3.10.3
- **State Management**: Riverpod
- **Storage**: Hive (local NoSQL)
- **Multi-Window**: desktop_multi_window (separate processes)
- **Code Editor**: re_editor (native Flutter)

## Project Structure

```
lib/
├── main.dart                 # App entry, window routing
├── models/
│   └── project.dart          # Project and Session models
├── providers/
│   ├── ai_provider.dart      # AI configuration state
│   └── project_provider.dart # Project CRUD operations
├── screens/
│   ├── ai_chat_screen.dart   # AI chat interface
│   ├── project_detail_screen.dart # Project view with files
│   ├── projects_screen.dart  # Project list
│   └── settings_screen.dart  # API key management
├── services/
│   ├── ai_service.dart       # Multi-provider AI client
│   └── file_service.dart     # File I/O operations
└── windows/
    ├── ai_chat_window.dart   # Separate AI chat window
    └── file_editor_window.dart # Separate file editor
```

## Governance Files

Each project can include these AI governance files:
- `AI_RULES_AND_BEST_PRACTICES.md` - AI behavior guidelines
- `AI_CONTEXT_INDEX.md` - Project context map
- `TODO.md` - Task tracking
- `SESSION_NOTES.md` - Development session history

## License

MIT License

---

**Last Updated**: December 6, 2025
