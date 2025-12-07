# AI Context Index - ABS Platform

## Project Overview

**Name**: ABS Platform (AI-Bootstrap System Platform)  
**Type**: Cross-Platform Desktop/Mobile Application (Flutter)  
**Purpose**: End-to-end AI project development with governance — any industry, any platform  
**Current Version**: 0.3.0-alpha  
**Status**: Active Development

## Vision Statement

> "End-to-End AI Project Development. Any Industry. Any Platform. Governed."

ABS Platform is not just for software development. It's a governed environment where AI agents help with ANY project type — software, finance, marketing, consulting, research, operations — across ALL platforms (desktop, mobile, web).

## Target Industries & Use Cases

| Industry | Project Types | AI Capabilities |
|----------|---------------|-----------------|
| **Software** | Apps, APIs, websites | Code, testing, deployment |
| **Finance** | Excel models, reports | VBA, data processing, analysis |
| **Marketing** | Campaigns, content | Copy, strategy, analytics |
| **Consulting** | Deliverables, decks | Research, documents, presentations |
| **Legal** | Contracts, compliance | Drafting, review, tracking |
| **Research** | Papers, experiments | Analysis, writing, citations |
| **Operations** | SOPs, workflows | Documentation, automation |

## Platform Support

| Platform | Status |
|----------|--------|
| Windows | ✅ Available |
| macOS | ✅ Available |
| Linux | 🔜 Coming |
| iOS | 🔜 Coming |
| Android | 🔜 Coming |
| Web | 🔜 Coming |

## Governance Files

| File | Purpose |
|------|---------|
| `AI_RULES_AND_BEST_PRACTICES.md` | Project-wide rules & constraints |
| `AI_CONTEXT_INDEX.md` | Shared knowledge & quick reference |
| `TODO.md` | Task queue and roadmap |
| `SESSION_NOTES.md` | Historical session log (completed work) |
| `PASSDOWN.md` | **Living context** for session/agent continuity |

### PASSDOWN.md — The Continuity Document

PASSDOWN.md is the most important governance file for AI continuity:

- **Auto-updated** on every "Close & Save" or manual trigger
- **Auto-read** by AI on session start (injected into system prompt)
- **Semantic archiving**: Entries marked "Complete" move to Archive section
- **Structure**:
  - Active Context (current work, status, blockers, next steps)
  - Archive (completed entries in collapsible `<details>` tags)

**Why it matters**: Without PASSDOWN, every AI session starts from scratch. With PASSDOWN, the AI knows where you left off, what's blocked, and what to do next.

## Key Files to Know

### Core Application

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point, Hive init, window routing |
| `lib/screens/project_detail_screen.dart` | Project view, file explorer, heartbeat checker |
| `lib/screens/ai_chat_screen.dart` | AI chat, file operations, heartbeat writer, session notes |
| `lib/windows/ai_chat_window.dart` | Separate window wrapper, "Close & Save" button |
| `lib/windows/file_editor_window.dart` | Separate window file editor (re_editor) |
| `lib/models/project.dart` | Project, Session, SessionTopic models |

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

```text
=== CREATE: path/to/file.txt ===
content here
=== END ===

=== UPDATE: existing/file.md ===
new content
=== END ===

=== DELETE: path/to/file.txt ===
=== DELETE: folder/ ===  (trailing slash for folders)
```

**IMPORTANT**: AI only performs file operations when explicitly asked by user.

## Session/Heartbeat System

### How It Works

1. Chat window writes `.abs_session_heartbeat` file every **500ms** with timestamp
2. Main window checks heartbeat file every **1 second**
3. If heartbeat > **1 second** old → window crashed → auto-complete session
4. "Close & Save" button: updates SESSION_NOTES.md, stops session, deletes heartbeat
5. **Pre-session check**: Before opening/creating sessions, checks for active heartbeat
6. **Accumulated duration**: Sessions track total time across multiple open/close cycles

### Session Notes Auto-Update

- **Manual**: "Update Notes" button always updates SESSION_NOTES.md
- **Auto (Close & Save)**: Smart logic decides if update is needed:
  - File operations since last update → Always update
  - New topics since last update → Always update
  - Only messages → Ask AI if meaningful
- **AI Summary**: Generates title, summary, topics, key decisions, files modified

### Runtime Files (in project directory)

- `.abs_session_heartbeat` - Timestamp file while chat window is open
- `.abs_chat_history.json` - Project state for main window sync

## Completed Features ✅

- Project management (create, list, delete)
- AI chat with OpenAI, Anthropic, Gemini
- AI file CREATE/UPDATE/DELETE operations (conservative mode)
- Subfolder support for all operations
- Live file updates (FileSystemWatcher)
- Directory navigation with breadcrumbs
- User create/delete files and folders
- File editor in separate floating windows (re_editor)
- Session auto-stop on window close (heartbeat)
- OneDrive compatibility (Windows rmdir command)
- Session timing fixes (accumulated duration, negative duration protection)
- Fast heartbeat detection (500ms write, 1s stale, ~2s max detection)
- Pre-session heartbeat check (prevents opening during active session)
- **Session notes auto-update with AI summaries**
- **Smart update logic (hard-coded + AI-decided)**
- **Topic tracking with #topic: tags**
- **AI milestone prompts**

## Future Vision: Multi-Agent Governed Workflows

### The Vision

Not just one AI chatbot — but a **team of governed AI agents** that can work on any project type, in any industry, on any platform. All agents follow your project's rules.

### Governance Files (All Agents Obey)

```text
AI_RULES_AND_BEST_PRACTICES.md  ← Project-wide rules & constraints
AI_CONTEXT_INDEX.md             ← Shared knowledge & quick reference
TODO.md                         ← Task queue
PASSDOWN.md                     ← Agent-to-agent communication (future)
```

### Multi-Agent Workflow (Future)

- Multiple session windows running simultaneously
- Each window = one "agent" with specific focus
- Agents coordinate via PASSDOWN.md
- All agents follow governance files
- Human oversight of all agent activity

### Roadmap

1. **Phase 1: Multi-Session Windows**
   - Multiple session windows open at once
   - Session-specific heartbeats
   - Independent chat histories

2. **Phase 2: Agent Identity & Coordination**
   - Named agents with roles
   - PASSDOWN.md for agent communication
   - Task claiming and handoff

3. **Phase 3: Governed Agent Teams**
   - Specialized agents (Research Agent, Code Agent, Test Agent)
   - All agents obey governance files
   - Human oversight dashboard

---

**Last Updated**: December 7, 2025 (Session 7)
**See Also**: SESSION_NOTES.md, TODO.md
