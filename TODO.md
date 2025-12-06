# TODO - ABS Platform

## 🔥 High Priority - Core Features

### 1. File Editor Enhancements

- [ ] Add syntax highlighting to re_editor (configure CodeHighlightTheme)
- [ ] Add line numbers display
- [ ] Add code folding indicators
- [ ] Configure language-specific highlighting (Markdown, Dart, etc.)

### 2. Sessions Management

- [ ] Create Session model
- [ ] Add session creation UI
- [ ] Load/save sessions to Hive

### 3. File Auto-Refresh

- [ ] Update UI after AI modifies files
- [ ] Show notification when files change

## ✅ Completed

- [x] Add Floating Action Button (FAB)
- [x] Fix Scaffold bracket structure bug
- [x] Fix model selector bug (parameter order)
- [x] File viewer with separate floating windows
- [x] File editor with save functionality
- [x] Replace Monaco/WebView with re_editor (native Flutter)
- [x] Fix crash on window close (separate window processes)
- [x] Add scroll controllers for better selection performance
- [x] Modified file indicator and unsaved changes tracking

## 🐛 Known Bugs

1. **Old Project Data** - Null subtype error (NON-BLOCKING)

## 📝 Technical Notes

**WebView + Multi-Window Incompatibility**: Monaco Editor (WebView2) cannot be used in `desktop_multi_window` separate processes due to crash on window destruction. Solution: Use native Flutter editors like `re_editor`.

---

**Last Updated**: December 6, 2025
