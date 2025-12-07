# TODO - ABS Platform

## 🔥 High Priority - Current Focus

### PASSDOWN.md System ✅ (Session 7 - COMPLETED)
- [x] Generate PASSDOWN entry on every "Close & Save"
- [x] "Update Passdown" manual button in chat header
- [x] Auto-inject PASSDOWN into AI system prompt on session start
- [x] Semantic archiving (status=Complete → moves to Archive)
- [x] Structured entries: Status, Working On, Next Steps, Blockers, Key Decisions
- [x] All 3 AI providers updated to understand PASSDOWN context

### API Cost Optimization ✅ (Session 8 - COMPLETED)
- [x] Single API call for Close & Save (SESSION_NOTES + PASSDOWN combined)
- [x] Trivial session skip (<2 messages, no file ops → no API call)
- [x] Topics bar cleanup (removed X buttons, read-only)

### Windows Distribution ✅ (Session 8 - COMPLETED)
- [x] Build release version (`flutter build windows --release`)
- [x] Create distributable folder
- [x] Create Inno Setup installer script with setup wizard
- [x] Installer config import on first launch

### Code Signing & App Store Distribution (BEFORE PRO LAUNCH)

**Windows** (~$350-600/year)
- [ ] Research EV Code Signing providers (SSL.com, Sectigo, DigiCert)
- [ ] Purchase EV certificate - instant SmartScreen trust
- [ ] Integrate signing into build/installer process

**Apple - macOS & iOS** ($99/year - one subscription covers both)
- [ ] Enroll in Apple Developer Program
- [ ] Set up code signing certificates in Xcode
- [ ] Configure notarization for macOS distribution
- [ ] Prepare App Store Connect for iOS submission

**Android** (Free)
- [ ] Generate release keystore (`keytool -genkey`)
- [ ] Configure `key.properties` for release builds
- [ ] Enroll in Google Play Console ($25 one-time) if targeting Play Store
- [ ] Set up Play App Signing

**Linux** (Free)
- [ ] Generate GPG signing key for package signatures
- [ ] Document verification process for users

**Total Annual Cost**: ~$450-700/year for full cross-platform signed distribution

### Session Notes Auto-Update System ✅ (Session 7 - COMPLETED)
- [x] "Update Notes" button in chat header for manual updates
- [x] "Close & Save" auto-updates SESSION_NOTES.md with AI summary
- [x] Smart hybrid update logic (hard-coded + AI-decided)
- [x] AI milestone prompts (after 5 file ops, 15 messages, or 3 topics)
- [x] Topic tracking with `#topic:` tags in chat
- [x] Duplicate prevention (tracks message count at last update)
- [x] AI decides if new messages are "meaningful" before updating

### Python Script Execution (NEXT FOCUS)
- [ ] Add Python detection and path configuration
- [ ] Implement script execution in sandboxed environment
- [ ] Capture and display script output in AI chat
- [ ] Allow AI to create and run Python scripts with `=== EXECUTE: script.py ===` format
- [ ] Handle script errors and display meaningful messages

## 🚀 Future Roadmap

### Phase 1: Multi-Session Windows
- [ ] Multiple session windows open simultaneously
- [ ] Session-specific heartbeat files (`.abs_heartbeat_{sessionId}`)
- [ ] Independent sessions working on different aspects
- [ ] Session-to-session context passing

### Phase 2: Multi-Agent Architecture
- [ ] Agent identity system (each window knows which "agent" it is)
- [x] **PASSDOWN.md** - Shared communication file between agents ✅
- [ ] Task queue system (agents claim tasks, mark complete)
- [ ] Dependency tracking ("blocked by Agent 2")
- [ ] Conflict resolution for simultaneous file edits

### Phase 3: Governed Agent Teams
- [ ] All agents obey governance files (AI_RULES, AI_CONTEXT_INDEX)
- [ ] Agents can post tasks for other agents
- [ ] Human oversight dashboard showing all agent activity
- [ ] Agent specialization (UI Agent, API Agent, Test Agent)

### Excel/VBA Operations (via Python)
- [ ] Excel file reading/writing support (openpyxl, pandas)
- [ ] Display Excel content in tabular view
- [ ] VBA extraction from Excel files (xlwings or win32com)
- [ ] VBA injection into Excel files
- [ ] AI-assisted VBA code generation

## ⏳ Medium Priority

### SESSION_NOTES.md Improvements
- [ ] Update/merge existing session entries instead of always inserting new
- [ ] Table of contents at top of file
- [ ] Search across all sessions

### File Editor Enhancements
- [ ] Add syntax highlighting to re_editor (configure CodeHighlightTheme)
- [ ] Add line numbers display
- [ ] Add code folding indicators
- [ ] Configure language-specific highlighting (Markdown, Dart, Python)

### UI Enhancements
- [ ] Markdown rendering in file viewer
- [ ] Search/replace in file editor
- [ ] File rename functionality
- [ ] Multi-project dashboard view

## ✅ Completed

### Session Notes & Topic System ✅ (Session 7 - December 7, 2025)
- [x] SessionTopic model with name, summary, isUserDefined, createdAt
- [x] Topic tracking in Session model (topics, summary, keyDecisions)
- [x] `#topic:` tag parsing in chat messages
- [x] Topic chips bar in chat UI
- [x] "Update Notes" button - manual SESSION_NOTES.md update
- [x] "Close & Save" - smart auto-update with AI summary
- [x] Smart hybrid logic: file ops/topics = always update, messages-only = AI decides
- [x] AI meaningful content check ("Is this worth documenting?")
- [x] Duplicate prevention based on activity tracking
- [x] AI milestone prompts after significant progress
- [x] Conservative AI file operations (only when explicitly asked)
- [x] Removed duplicate Close & Save buttons (kept blue one in title bar)

### Session Timing & Heartbeat Improvements ✅ (Session 6)
- [x] Fix `copyWith(endedAt: null)` not clearing endedAt (added `clearEndedAt` flag)
- [x] Add negative duration protection in duration getter
- [x] Implement `accumulatedDuration` tracking across session reopens
- [x] Speed up heartbeat (500ms write, 1s stale, 1s check)
- [x] Add pre-session heartbeat check to prevent opening during active session
- [x] Show "A session is already active" message when another window is open

### Session Auto-Stop Feature ✅ (Session 5)
- [x] Fix first-click API key error (wait for keys to load)
- [x] Heartbeat mechanism for crashed window detection
- [x] "Close & Save" button for proper session stop
- [x] Auto-complete sessions when heartbeat goes stale

### AI File Operations ✅
- [x] AI file operations (CREATE, UPDATE, DELETE)
- [x] Subfolder support for all file operations
- [x] AI folder deletion with trailing slash syntax
- [x] Fix AI file append (regex for multi-line content)
- [x] Pre-load ALL project files into AI context
- [x] Conservative file operation prompts (only when explicitly asked)

### File Management ✅
- [x] Live file updates with FileSystemWatcher (recursive)
- [x] Directory navigation with breadcrumbs
- [x] Expandable folder tree view
- [x] User create file/folder UI with templates
- [x] User delete file/folder with confirmation
- [x] OneDrive compatibility fix (rmdir command)
- [x] Separate window Hive error fix (isInSeparateWindow flag)

### Core Features ✅
- [x] File viewer with separate floating windows
- [x] File editor with save functionality (re_editor)
- [x] Fix crash on window close (separate window processes)
- [x] Session creation and tracking
- [x] Chat history persistence across windows

## 🐛 Known Bugs

1. **Old Project Data** - Null subtype error (NON-BLOCKING)
2. **MissingPluginException** - setFrameAutosaveName (macOS method on Windows, non-blocking)
3. **HeartbeatChecker** - FormatException on invalid date (non-blocking, handled)

## 📝 Technical Notes

### Smart Session Notes Update Logic

```
User clicks "Update Notes" → Always update (forceUpdate: true)
User clicks "Close & Save" → Smart logic (forceUpdate: false):
  1. New file operations since last update? → Update
  2. New topics added since last update? → Update  
  3. Only new messages? → Ask AI if meaningful
  4. AI says "yes" → Update
  5. AI says "no" → Skip (avoid clutter)
```

### Multi-Agent Vision

```
┌─────────────────────────────────────────────────────────────┐
│                   GOVERNANCE LAYER                          │
│  AI_RULES_AND_BEST_PRACTICES.md ← All agents obey          │
│  AI_CONTEXT_INDEX.md ← Shared project knowledge            │
│  TODO.md ← Task queue                                       │
│  PASSDOWN.md ← Agent-to-agent communication                │
└─────────────────────────────────────────────────────────────┘
                    ▲           ▲           ▲
              ┌─────┴───┐ ┌─────┴───┐ ┌─────┴───┐
              │ Agent 1 │ │ Agent 2 │ │ Agent 3 │
              │ (UI)    │ │ (API)   │ │ (Tests) │
              └─────────┘ └─────────┘ └─────────┘
```

---

**Last Updated**: December 7, 2025 (Session 8)
- `openpyxl` - Read/write Excel files (.xlsx)
- `pandas` - Data analysis with Excel support
- `xlwings` - Full Excel/VBA automation (requires Excel)
- `win32com.client` - Windows COM for VBA macros

### Architecture Reminders
- Separate windows are separate OS processes (no shared memory)
- Use file-based sync for cross-window communication
- Heartbeat files detect crashed windows (500ms write, 1s stale threshold)
- Hive only accessible from main window
- Pre-session heartbeat check prevents race conditions

---

**Last Updated**: December 7, 2025
