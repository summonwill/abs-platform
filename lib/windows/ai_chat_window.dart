/// ABS Platform - AI Chat Window (Separate OS Window)
/// 
/// Purpose: Entry point for separate AI chat windows spawned via desktop_multi_window
/// Key Components:
///   - Window initialization (no Hive - API keys passed via arguments)
///   - Custom title bar with save-before-close functionality
///   - AIChatScreen integration in isolated window process
///   - Project data reconstruction from JSON arguments
/// 
/// Dependencies:
///   - desktop_multi_window: Multi-window infrastructure
///   - ai_chat_screen: Chat UI component
/// 
/// Last Modified: December 6, 2025
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../screens/ai_chat_screen.dart';
import '../models/project.dart';
import '../providers/ai_provider.dart';

/// Separate window for AI chat
/// 
/// Receives project data and API keys via window arguments
/// (Hive is locked by main window process, so keys must be passed explicitly)
class AIChatWindow extends StatefulWidget {
  final WindowController controller;
  final Map<String, dynamic> args;

  const AIChatWindow({
    super.key,
    required this.controller,
    required this.args,
  });

  @override
  State<AIChatWindow> createState() => _AIChatWindowState();
}

class _AIChatWindowState extends State<AIChatWindow> {
  late final AIKeys _apiKeys;
  late final Project _project;
  final GlobalKey<dynamic> _chatScreenKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    // Extract API keys from arguments (passed from main window)
    final apiKeysData = widget.args['apiKeys'] as Map<String, dynamic>?;
    _apiKeys = AIKeys(
      openAI: apiKeysData?['openai'] as String?,
      anthropic: apiKeysData?['anthropic'] as String?,
      gemini: apiKeysData?['gemini'] as String?,
    );
    
    // Reconstruct project from args (excluding apiKeys)
    final projectData = Map<String, dynamic>.from(widget.args)..remove('apiKeys');
    _project = Project.fromJson(projectData);
    
    print('DEBUG AIChatWindow: API keys loaded - OpenAI: ${_apiKeys.openAI != null}, Anthropic: ${_apiKeys.anthropic != null}, Gemini: ${_apiKeys.gemini != null}');
  }
  
  /// Save the session and then close the window
  /// This updates SESSION_NOTES.md with AI summary before closing (if meaningful)
  Future<void> _saveAndClose() async {
    print('DEBUG: Close button pressed - updating session notes and stopping session');
    try {
      final state = _chatScreenKey.currentState;
      if (state != null) {
        // Update session notes with smart logic (AI decides if meaningful)
        await state.updateSessionNotes(showSuccessMessage: false, forceUpdate: false);
        // Then stop the session
        await state.stopSessionOnClose();
      }
    } catch (e) {
      print('DEBUG: Error during save and close: $e');
    }
    
    // Close the window
    await widget.controller.close();
  }
  
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        // Override aiKeysProvider with pre-loaded keys (no Hive access needed)
        aiKeysProvider.overrideWith((ref) => AIKeysNotifier.withKeys(_apiKeys)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.dark,
        home: Material(
          color: const Color(0xFF1E1E1E),
          child: Column(
            children: [
              // Custom title bar with close button that saves session
              Container(
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF2D2D2D),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF3D3D3D), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.smart_toy, size: 20, color: Colors.blue[300]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Assistant - ${_project.name}',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Close & Save button - prominent styling
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Close & Save'),
                        onPressed: _saveAndClose,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          minimumSize: const Size(0, 32),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              // Chat content
              Expanded(
                child: AIChatScreen(
                  key: _chatScreenKey,
                  project: _project, 
                  isInSeparateWindow: true,
                  initialApiKeys: _apiKeys,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
