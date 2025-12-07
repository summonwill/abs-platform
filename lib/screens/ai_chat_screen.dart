/// ABS Platform - AI Chat Screen
/// 
/// Purpose: Conversational AI interface with project context awareness
/// Key Components:
///   - Message display with user/AI distinction
///   - Model selector (OpenAI, Anthropic, Gemini)
///   - Conversation history persistence
///   - File update detection from AI responses
///   - Project context injection (governance files)
/// 
/// Dependencies:
///   - ai_service: Multi-provider AI API client
///   - ai_provider: API key and settings management
///   - project_provider: Project and session state
/// 
/// Last Modified: December 6, 2025
library;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../services/ai_service.dart';
import '../providers/ai_provider.dart';
import '../providers/project_provider.dart';

/// AI chat screen with conversation history and context awareness
class AIChatScreen extends ConsumerStatefulWidget {
  final Project project;
  final bool isInSeparateWindow;
  final VoidCallback? onCloseRequested;
  final AIKeys? initialApiKeys; // Pass directly for separate windows

  const AIChatScreen({
    super.key, 
    required this.project, 
    this.isInSeparateWindow = false,
    this.onCloseRequested,
    this.initialApiKeys,
  });

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle to save on close
    WidgetsBinding.instance.addObserver(this);
    _loadConversationHistory();
    
    // Start heartbeat for separate windows so main window can detect if we crash
    if (widget.isInSeparateWindow) {
      _startHeartbeat();
    }
  }
  
  /// Write a heartbeat file periodically so main window knows we're alive
  void _startHeartbeat() {
    _writeHeartbeat(); // Write immediately
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _writeHeartbeat();
    });
  }
  
  Future<void> _writeHeartbeat() async {
    try {
      final file = File('${widget.project.path}${Platform.pathSeparator}.abs_session_heartbeat');
      await file.writeAsString(DateTime.now().toIso8601String());
    } catch (e) {
      // Ignore errors - heartbeat is best effort
    }
  }
  
  Future<void> _deleteHeartbeat() async {
    try {
      final file = File('${widget.project.path}${Platform.pathSeparator}.abs_session_heartbeat');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    print('DEBUG: AIChatScreen dispose called, isInSeparateWindow=${widget.isInSeparateWindow}');
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Auto-stop session when window closes (only for separate windows)
    if (widget.isInSeparateWindow) {
      // Note: Can't await in dispose, but we try anyway
      _deleteHeartbeat();
      stopSessionOnClose();
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('DEBUG: App lifecycle state changed to $state');
    // Save session when app is paused, inactive, or detached
    if (widget.isInSeparateWindow && 
        (state == AppLifecycleState.paused || 
         state == AppLifecycleState.inactive ||
         state == AppLifecycleState.detached)) {
      print('DEBUG: Saving session due to lifecycle change');
      stopSessionOnClose();
    }
  }
  
  /// Stop the active session when the chat window is closed
  /// Saves final state to file so main window can sync it
  /// Made public so it can be called from parent window before close
  Future<void> stopSessionOnClose() async {
    try {
      // Cancel heartbeat first so main window doesn't re-complete the session
      _heartbeatTimer?.cancel();
      await _deleteHeartbeat();
      
      // Find active session
      final activeSession = widget.project.sessions.firstWhere(
        (s) => s.isActive,
        orElse: () => Session(projectId: '', title: ''),
      );
      
      if (activeSession.projectId.isEmpty) {
        print('DEBUG: No active session to stop');
        return;
      }
      
      // Update session to completed with end time
      final updatedSession = activeSession.copyWith(
        status: SessionStatus.completed,
        endedAt: DateTime.now(),
        conversationHistory: _messages.map((m) => m.toJson()).toList(),
      );
      
      // Update project with stopped session
      final updatedSessions = widget.project.sessions.map((s) {
        return s.id == updatedSession.id ? updatedSession : s;
      }).toList();
      
      final updatedProject = widget.project.copyWith(
        sessions: updatedSessions,
        lastModified: DateTime.now(),
      );
      
      // Save to file
      await _saveToFile(updatedProject);
      print('DEBUG: Auto-stopped session on window close');
    } catch (e) {
      print('DEBUG: Failed to auto-stop session: $e');
    }
  }

  /// Load conversation history from active session
  /// 
  /// Finds the active session in the project and populates
  /// the messages list with previous conversation.
  /// For separate windows, also tries to load from JSON file.
  /// 
  /// Side Effects:
  ///   - Clears current messages
  ///   - Populates _messages from session.conversationHistory or file
  ///   - Scrolls to bottom after loading
  Future<void> _loadConversationHistory() async {
    // In separate windows, try to load from file first (may have newer data)
    if (widget.isInSeparateWindow) {
      await _loadFromFile();
      return;
    }
    
    // Load conversation from active session if exists
    _loadFromActiveSession(widget.project);
  }
  
  void _loadFromActiveSession(Project project) {
    final activeSession = project.sessions.firstWhere(
      (s) => s.isActive,
      orElse: () => Session(projectId: '', title: ''),
    );

    if (activeSession.projectId.isNotEmpty && activeSession.conversationHistory.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(
          activeSession.conversationHistory.map((json) => ChatMessage.fromJson(json)),
        );
      });
      
      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messages.isNotEmpty) {
          _scrollToBottom();
        }
      });
    }
  }
  
  /// Load conversation history from JSON file (for separate windows)
  Future<void> _loadFromFile() async {
    try {
      final file = File('${widget.project.path}${Platform.pathSeparator}.abs_chat_history.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        final savedProject = Project.fromJson(json);
        
        // Find the active session and load its history
        _loadFromActiveSession(savedProject);
        print('DEBUG: Loaded chat history from file');
      } else {
        // File doesn't exist, load from project args (which contains conversation history)
        print('DEBUG: No chat history file, loading from project args');
        _loadFromActiveSession(widget.project);
      }
    } catch (e) {
      print('DEBUG: Failed to load chat history from file: $e');
      // Fall back to project data
      _loadFromActiveSession(widget.project);
    }
  }

  /// Save current conversation to active session
  /// 
  /// Persists the messages list to the active session's
  /// conversationHistory field and updates the project.
  /// 
  /// Side Effects:
  ///   - Updates session in project sessions list
  ///   - Saves project to Hive via ProjectsNotifier (main window only)
  ///   - Saves to .abs_chat_history.json file (separate windows)
  ///   - Updates selectedProjectProvider state
  /// 
  /// Does nothing if no active session exists
  Future<void> _saveConversationHistory() async {
    // Find active session
    final activeSession = widget.project.sessions.firstWhere(
      (s) => s.isActive,
      orElse: () => Session(projectId: '', title: ''),
    );

    if (activeSession.projectId.isEmpty) return;

    // Update session with conversation history
    final updatedSession = activeSession.copyWith(
      conversationHistory: _messages.map((m) => m.toJson()).toList(),
    );

    // Update project with new session
    final updatedSessions = widget.project.sessions.map((s) {
      return s.id == updatedSession.id ? updatedSession : s;
    }).toList();

    final updatedProject = widget.project.copyWith(
      sessions: updatedSessions,
      lastModified: DateTime.now(),
    );

    // In separate windows, we can't access Hive, so save to a file
    if (widget.isInSeparateWindow) {
      await _saveToFile(updatedProject);
    } else {
      await ref.read(projectsProvider.notifier).updateProject(updatedProject);
      ref.read(selectedProjectProvider.notifier).state = updatedProject;
    }
  }
  
  /// Save project data to a JSON file for persistence from separate windows
  Future<void> _saveToFile(Project project) async {
    try {
      final file = File('${project.path}${Platform.pathSeparator}.abs_chat_history.json');
      final json = jsonEncode(project.toJson());
      await file.writeAsString(json);
      print('DEBUG: Saved chat history to ${file.path}');
    } catch (e) {
      print('DEBUG: Failed to save chat history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiKeys = ref.watch(aiKeysProvider);
    final selectedProvider = ref.watch(selectedAIProviderProvider);
    
    final hasAnyKey = aiKeys.openAI != null || 
                      aiKeys.anthropic != null || 
                      aiKeys.gemini != null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            _buildProviderSelector(),
            const SizedBox(width: 8),
            _buildModelSelector(),
          ],
        ),
        actions: [
          // Copy all button
          IconButton(
            icon: const Icon(Icons.copy_all),
            onPressed: _messages.isEmpty ? null : _copyEntireConversation,
            tooltip: 'Copy entire conversation',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _messages.isEmpty ? null : _clearChat,
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: !hasAnyKey
          ? _buildNoAPIKeyState()
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessagesList(),
                ),
                _buildInputArea(selectedProvider),
              ],
            ),
    );
  }

  Widget _buildProviderSelector() {
    final aiKeys = ref.watch(aiKeysProvider);
    final selectedProvider = ref.watch(selectedAIProviderProvider);

    return PopupMenuButton<AIProvider>(
      icon: Icon(_getProviderIcon(selectedProvider)),
      tooltip: 'Select AI provider',
      onSelected: (provider) {
        ref.read(selectedAIProviderProvider.notifier).state = provider;
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AIProvider.openai,
          enabled: aiKeys.openAI != null,
          child: Row(
            children: [
              Icon(_getProviderIcon(AIProvider.openai)),
              const SizedBox(width: 8),
              const Text('OpenAI (GPT-4o)'),
              if (aiKeys.openAI == null) ...[
                const Spacer(),
                Icon(Icons.lock, size: 16, color: Colors.grey),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: AIProvider.anthropic,
          enabled: aiKeys.anthropic != null,
          child: Row(
            children: [
              Icon(_getProviderIcon(AIProvider.anthropic)),
              const SizedBox(width: 8),
              const Text('Anthropic (Claude)'),
              if (aiKeys.anthropic == null) ...[
                const Spacer(),
                Icon(Icons.lock, size: 16, color: Colors.grey),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: AIProvider.gemini,
          enabled: aiKeys.gemini != null,
          child: Row(
            children: [
              Icon(_getProviderIcon(AIProvider.gemini)),
              const SizedBox(width: 8),
              const Text('Google (Gemini)'),
              if (aiKeys.gemini == null) ...[
                const Spacer(),
                Icon(Icons.lock, size: 16, color: Colors.grey),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelSelector() {
    final selectedProvider = ref.watch(selectedAIProviderProvider);
    final selectedModels = ref.watch(selectedModelProvider);
    final currentModel = selectedModels[selectedProvider] ?? 'default';
    
    final models = availableModels[selectedProvider] ?? [];
    
    return PopupMenuButton<String>(
      tooltip: 'Select model',
      onSelected: (model) {
        final updatedModels = {...selectedModels};
        updatedModels[selectedProvider] = model;
        ref.read(selectedModelProvider.notifier).state = updatedModels;
      },
      itemBuilder: (context) => models.map((model) {
        return PopupMenuItem<String>(
          value: model['id'] as String,
          child: Row(
            children: [
              Text(model['name'] as String),
              const Spacer(),
              Text(
                model['cost'] as String,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      }).toList(),
      child: Chip(
        avatar: const Icon(Icons.tune, size: 18),
        label: Text(_getModelDisplayName(currentModel)),
      ),
    );
  }
  
  String _getModelDisplayName(String modelId) {
    if (modelId.contains('gpt-4o-mini')) return 'Mini';
    if (modelId.contains('gpt-4o')) return '4o';
    if (modelId.contains('gpt-3.5')) return '3.5';
    if (modelId.contains('claude-3-5-sonnet')) return 'Sonnet';
    if (modelId.contains('claude-3-opus')) return 'Opus';
    if (modelId.contains('claude-3-haiku')) return 'Haiku';
    if (modelId.contains('gemini-2.0')) return '2.0';
    if (modelId.contains('gemini-1.5')) return '1.5';
    return 'Model';
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return Icons.psychology;
      case AIProvider.anthropic:
        return Icons.smart_toy;
      case AIProvider.gemini:
        return Icons.auto_awesome;
    }
  }

  Widget _buildNoAPIKeyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.key,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No AI API Keys Configured',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your OpenAI, Anthropic, or Google API key in settings to start chatting with AI.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to settings
              },
              icon: const Icon(Icons.settings),
              label: const Text('Go to Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Start a conversation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the AI to help manage your project, update TODO items, or maintain session notes.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Review my TODO list'),
                _buildSuggestionChip('Start a new session'),
                _buildSuggestionChip('Update project status'),
                _buildSuggestionChip('Add a new task'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () async {
        // Use passed keys for separate windows, provider for main window
        final aiKeys = widget.isInSeparateWindow && widget.initialApiKeys != null
            ? widget.initialApiKeys!
            : ref.read(aiKeysProvider);
        
        if (!aiKeys.hasAnyKey) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('API keys not ready. Please try again.')),
            );
          }
          return;
        }
        
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessagesList() {
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onSecondaryTapUp: (details) => _showMessageContextMenu(context, details.globalPosition, message),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUser
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser ? Icons.person : Icons.smart_toy,
                    size: 16,
                    color: isUser
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUser ? 'You' : 'AI Assistant',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isUser
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  // Copy button
                  InkWell(
                    onTap: () => _copyMessageToClipboard(message),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy,
                        size: 14,
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message.content,
                style: TextStyle(
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            if (message.fileUpdates.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Updated ${message.fileUpdates.length} file(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...message.fileUpdates.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(left: 24, top: 2),
                    child: Text(
                      '• ${entry.key}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  )),
            ],
          ],
        ),
        ),
      ),
    );
  }
  
  /// Copy a single message to clipboard
  void _copyMessageToClipboard(ChatMessage message) {
    final prefix = message.isUser ? 'You: ' : 'AI: ';
    Clipboard.setData(ClipboardData(text: '$prefix${message.content}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  /// Copy entire conversation to clipboard
  void _copyEntireConversation() {
    final buffer = StringBuffer();
    for (final message in _messages) {
      final prefix = message.isUser ? 'You: ' : 'AI: ';
      buffer.writeln('$prefix${message.content}');
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${_messages.length} messages to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// Show context menu for a message
  void _showMessageContextMenu(BuildContext context, Offset position, ChatMessage message) {
    final messageIndex = _messages.indexOf(message);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          onTap: () => _copyMessageToClipboard(message),
          child: const Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Copy this message'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => _copyMessagesFromIndex(messageIndex),
          child: const Row(
            children: [
              Icon(Icons.content_copy, size: 18),
              SizedBox(width: 8),
              Text('Copy from here to end'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: _copyEntireConversation,
          child: const Row(
            children: [
              Icon(Icons.select_all, size: 18),
              SizedBox(width: 8),
              Text('Copy entire conversation'),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Copy messages from a specific index to the end
  void _copyMessagesFromIndex(int startIndex) {
    final buffer = StringBuffer();
    for (int i = startIndex; i < _messages.length; i++) {
      final message = _messages[i];
      final prefix = message.isUser ? 'You: ' : 'AI: ';
      buffer.writeln('$prefix${message.content}');
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${_messages.length - startIndex} messages to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildInputArea(AIProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Ask AI to help with your project...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isLoading ? null : _sendMessage,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    // Check API keys are available before sending
    // Use passed keys for separate windows, provider for main window
    final aiKeys = widget.isInSeparateWindow && widget.initialApiKeys != null
        ? widget.initialApiKeys!
        : ref.read(aiKeysProvider);
    print('DEBUG _sendMessage: API keys check - OpenAI: ${aiKeys.openAI != null}, hasAnyKey: ${aiKeys.hasAnyKey}, usedInitial: ${widget.initialApiKeys != null}');
    if (!aiKeys.hasAnyKey) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No API keys available. Please configure in Settings.')),
        );
      }
      return;
    }

    _messageController.clear();
    
    setState(() {
      _messages.add(ChatMessage(content: message, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final aiService = ref.read(aiServiceProvider);
      final selectedProvider = ref.read(selectedAIProviderProvider);

      // Set API keys
      aiService.setAPIKeys(
        openAI: aiKeys.openAI,
        anthropic: aiKeys.anthropic,
        gemini: aiKeys.gemini,
      );

      // Get project context with ALL file contents pre-loaded
      // This gives the AI full access to every file in the project
      final fileService = ref.read(fileServiceProvider);
      final fullProjectData = await fileService.exportFullProjectForAI(widget.project.path);
      
      final projectContext = fullProjectData['governanceFiles'] as Map<String, String>? ?? {};
      final allFileContents = fullProjectData['allFileContents'] as Map<String, String>? ?? {};
      final fileTree = fullProjectData['fileTree'] as List<String>? ?? [];
      
      // Add ALL project files to context (not just governance files)
      // This way AI always has full access to read/modify any file
      for (var entry in allFileContents.entries) {
        projectContext['[FILE] ${entry.key}'] = entry.value;
      }

      // DEBUG: Check what we're sending
      print("DEBUG Project Context:");
      print("  Project Path: ${widget.project.path}");
      print("  Governance Files: ${projectContext.keys.where((k) => !k.startsWith('[FILE]')).toList()}");
      print("  Project Files Loaded: ${allFileContents.length}");
      print("  File Tree Count: ${fileTree.length}");
      if (projectContext.containsKey('TODO.md')) {
        print("  TODO.md preview: ${projectContext['TODO.md']?.substring(0, 100)}...");
      } else {
        print("  WARNING: TODO.md not found in context!");
      }

      // Build conversation history
      final history = _messages
          .where((m) => !m.isUser || _messages.indexOf(m) < _messages.length - 1)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      // DEBUG: Check model selection
      final selectedModel = ref.read(selectedModelProvider)[selectedProvider];
      print("DEBUG Model Selection:");
      print("  Provider: $selectedProvider");
      print("  Selected Model: $selectedModel");
      print("  Full Map: ${ref.read(selectedModelProvider)}");
      print("  File Tree Count: ${fileTree.length}");

      // Send to AI
      final response = await aiService.sendMessage(
        provider: selectedProvider,
        model: selectedModel,
        message: message,
        conversationHistory: history,
        projectContext: projectContext,
        fileTree: fileTree,
      );

      // Parse file updates
      final updates = aiService.parseFileUpdates(response);
      
      // DEBUG: Log what was parsed
      print('DEBUG File Operations Parsed:');
      print('  Response length: ${response.length}');
      print('  Updates found: ${updates.length}');
      if (updates.isNotEmpty) {
        print('  Operations:');
        for (var entry in updates.entries) {
          print('    - ${entry.key}: ${entry.value.length} chars');
        }
      }

      // Apply updates to files
      if (updates.isNotEmpty) {
        final fileService = ref.read(fileServiceProvider);
        final appliedUpdates = <String, String>{};
        
        for (var entry in updates.entries) {
          final key = entry.key;
          final content = entry.value;
          
          // Check if this is a file operation (CREATE/UPDATE/DELETE) or legacy governance file
          if (key.contains(':')) {
            // New format: "OPERATION:filepath"
            final parts = key.split(':');
            final operation = parts[0];
            final filepath = parts.sublist(1).join(':'); // Handle paths with colons
            
            bool success = false;
            switch (operation) {
              case 'CREATE':
              case 'UPDATE':
                success = await fileService.writeProjectFile(
                  widget.project.path,
                  filepath,
                  content,
                );
                if (success) {
                  appliedUpdates[filepath] = content;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${operation == 'CREATE' ? 'Created' : 'Updated'}: $filepath')),
                    );
                  }
                }
                break;
              case 'DELETE':
                // Check if it's a folder (ends with /) or a file
                final isFolder = filepath.endsWith('/');
                if (isFolder) {
                  success = await fileService.deleteProjectFolder(
                    widget.project.path,
                    filepath,
                  );
                } else {
                  success = await fileService.deleteProjectFile(
                    widget.project.path,
                    filepath,
                  );
                }
                if (success) {
                  appliedUpdates[filepath] = '[DELETED]';
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted: $filepath${isFolder ? ' (folder)' : ''}')),
                    );
                  }
                }
                break;
            }
            
            if (!success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to $operation: $filepath')),
              );
            }
          } else {
            // Legacy format: governance file update
            await fileService.writeGovernanceFile(
              widget.project.path,
              key,
              content,
            );
            appliedUpdates[key] = content;
          }
        }
        
        // Try to refresh the project's file list so UI updates
        // This will fail in separate windows (no Hive access) but that's OK
        // Skip refresh in separate windows to avoid Hive errors
        if (!widget.isInSeparateWindow) {
          try {
            final updatedProject = await ref.read(projectsProvider.notifier).refreshProjectFiles(widget.project.id);
            if (updatedProject != null) {
              // Also update selectedProjectProvider so project_detail_screen refreshes
              ref.read(selectedProjectProvider.notifier).state = updatedProject;
            }
          } catch (e) {
            // Expected in separate windows - file operations still work, just can't update main window
            print('Note: Could not refresh main window file list: $e');
          }
        }
        
        setState(() {
          _messages.add(ChatMessage(
            content: response,
            isUser: false,
            fileUpdates: appliedUpdates,
          ));
          _isLoading = false;
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            content: response,
            isUser: false,
          ));
          _isLoading = false;
        });
      }

      _scrollToBottom();
      
      // Save conversation history
      await _saveConversationHistory();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          content: 'Error: $e',
          isUser: false,
        ));
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<void> _clearChat() async {
    setState(() {
      _messages.clear();
    });
    await _saveConversationHistory();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final Map<String, String> fileUpdates;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.fileUpdates = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'isUser': isUser,
      'fileUpdates': fileUpdates,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      fileUpdates: Map<String, String>.from(json['fileUpdates'] ?? {}),
    );
  }
}
