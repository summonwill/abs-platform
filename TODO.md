# TODO - ABS Platform

## í´´ Critical - Blocking Development

### 1. Fix Model Selector Bug
- [ ] Restart Flutter app to view debug logs
- [ ] Analyze why model parameter is "test" instead of "gpt-4o-mini"
- [ ] Fix state reading in ai_chat_screen.dart
- [ ] Test with all three providers

## í¿¡ High Priority - Core Features

### 2. File Viewer Implementation
- [ ] Make files in _FilesTab clickable
- [ ] Add markdown rendering
- [ ] Enable editing and saving

### 3. Sessions Management
- [ ] Create Session model
- [ ] Add session creation UI
- [ ] Load/save sessions to Hive

### 4. File Auto-Refresh
- [ ] Update UI after AI modifies files
- [ ] Show notification when files change

## âœ… Completed

- [x] Add Floating Action Button (FAB)
- [x] Fix Scaffold bracket structure bug
- [x] Add debug logging for model selection

## í°› Known Bugs

1. **Model Selector** - AI API receives "test" instead of model ID (CRITICAL)
2. **Old Project Data** - Null subtype error (NON-BLOCKING)

---

**Last Updated**: December 5, 2025
