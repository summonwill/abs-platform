# TODO - ABS Platform

## 🔥 High Priority - Next Session

### Python Script Execution (NEXT FOCUS)

- [ ] Add Python detection and path configuration
- [ ] Implement script execution in sandboxed environment
- [ ] Capture and display script output in AI chat
- [ ] Allow AI to create and run Python scripts with `=== EXECUTE: script.py ===` format
- [ ] Handle script errors and display meaningful messages

### Excel/VBA Operations (via Python)

- [ ] Excel file reading/writing support (openpyxl, pandas)
- [ ] Display Excel content in tabular view
- [ ] VBA extraction from Excel files (xlwings or win32com)
- [ ] VBA injection into Excel files
- [ ] AI-assisted VBA code generation

## ⏳ Medium Priority

### File Editor Enhancements

- [ ] Add syntax highlighting to re_editor (configure CodeHighlightTheme)
- [ ] Add line numbers display
- [ ] Add code folding indicators
- [ ] Configure language-specific highlighting (Markdown, Dart, Python)

### UI Enhancements

- [ ] Markdown rendering in file viewer
- [ ] Search/replace in file editor
- [ ] File rename functionality

## ✅ Completed (December 6, 2025)

### Session Auto-Stop Feature ✅
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

## 📝 Technical Notes for Next Session

### Python Execution Implementation

```dart
// Suggested format for AI to execute scripts:
// === EXECUTE: script.py ===
// import pandas as pd
// df = pd.read_excel('data.xlsx')
// print(df.head())
// === END ===

// file_service.dart
Future<ProcessResult> executePythonScript(String projectPath, String scriptPath) async {
  return await Process.run('python', [scriptPath], 
    workingDirectory: projectPath,
    runInShell: true);
}
```

### Key Python Packages for Excel/VBA
- `openpyxl` - Read/write Excel files (.xlsx)
- `pandas` - Data analysis with Excel support
- `xlwings` - Full Excel/VBA automation (requires Excel)
- `win32com.client` - Windows COM for VBA macros

### Architecture Reminders
- Separate windows are separate OS processes (no shared memory)
- Use file-based sync for cross-window communication
- Heartbeat files detect crashed windows
- Hive only accessible from main window

---

**Last Updated**: December 6, 2025, 11:30 PM
