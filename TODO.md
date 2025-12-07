# TODO - ABS Platform

## 🔥 High Priority - Core Features

### 1. File Editor Enhancements

- [ ] Add syntax highlighting to re_editor (configure CodeHighlightTheme)
- [ ] Add line numbers display
- [ ] Add code folding indicators
- [ ] Configure language-specific highlighting (Markdown, Dart, Python)

### 2. Python Script Execution

- [ ] Add Python detection and path configuration
- [ ] Implement script execution in sandboxed environment
- [ ] Capture and display script output
- [ ] Allow AI to create and run Python scripts

### 3. Excel/VBA Operations

- [ ] Excel file reading/writing support
- [ ] VBA extraction from Excel files
- [ ] VBA injection into Excel files
- [ ] AI-assisted VBA code generation

## ⏳ Medium Priority

### 4. Sessions Management

- [ ] Session detail view
- [ ] Session end functionality
- [ ] Session history browser

### 5. UI Enhancements

- [ ] Markdown rendering in file viewer
- [ ] Search/replace in file editor
- [ ] File rename functionality

## ✅ Completed

### File Management (December 6, 2025)
- [x] AI file operations (CREATE, UPDATE, DELETE)
- [x] Subfolder support for all file operations
- [x] Live file updates with FileSystemWatcher (recursive)
- [x] Directory navigation with breadcrumbs
- [x] Expandable folder tree view
- [x] User create file/folder UI with templates
- [x] User delete file/folder with confirmation
- [x] Right-click context menus
- [x] OneDrive compatibility fix (rmdir command)
- [x] AI folder deletion with trailing slash syntax
- [x] Separate window Hive error fix (isInSeparateWindow flag)

### Core Features (December 5, 2025)
- [x] Add Floating Action Button (FAB)
- [x] Fix Scaffold bracket structure bug
- [x] Fix model selector bug (parameter order)
- [x] File viewer with separate floating windows
- [x] File editor with save functionality
- [x] Replace Monaco/WebView with re_editor (native Flutter)
- [x] Fix crash on window close (separate window processes)
- [x] Add scroll controllers for better selection performance
- [x] Modified file indicator and unsaved changes tracking
- [x] Session creation and tracking
- [x] SESSION_NOTES.md auto-update

## 🐛 Known Bugs

1. **Old Project Data** - Null subtype error (NON-BLOCKING)
2. **MissingPluginException** - setFrameAutosaveName (macOS method on Windows, non-blocking)

## 📝 Technical Notes

**WebView + Multi-Window Incompatibility**: Monaco Editor (WebView2) cannot be used in `desktop_multi_window` separate processes due to crash on window destruction. Solution: Use native Flutter editors like `re_editor`.

**OneDrive File Locking**: Dart's `Directory.delete()` fails on OneDrive-synced folders. Solution: Use Windows `rmdir /s /q` command via Process.run.

**Separate Window Hive Access**: Sub-windows run in separate processes without Hive initialization. Skip provider refresh calls in separate windows using `isInSeparateWindow` flag.

---

**Last Updated**: December 6, 2025
