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
  final List<SessionTopic> _sessionTopics = [];  // Track topics during session
  bool _isLoading = false;
  Timer? _heartbeatTimer;
  
  // Milestone tracking for AI prompts
  int _fileOperationsSinceLastUpdate = 0;
  int _messagesSinceLastUpdate = 0;
  int _topicChangesSinceLastUpdate = 0;
  bool _hasPromptedForUpdate = false;
  DateTime? _lastNotesUpdate;
  int _messageCountAtLastNotesUpdate = 0;  // Track when notes were last updated
  int _fileOpsAtLastNotesUpdate = 0;       // Track file ops at last update
  int _topicsAtLastNotesUpdate = 0;        // Track topics at last update

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle to save on close
    WidgetsBinding.instance.addObserver(this);
    _loadConversationHistory();
    
    // Ensure PASSDOWN.md exists for session continuity
    _ensurePassdownExists();
    
    // Start heartbeat for separate windows so main window can detect if we crash
    if (widget.isInSeparateWindow) {
      _startHeartbeat();
    }
  }
  
  /// Ensure PASSDOWN.md exists in the project directory
  /// Creates it if missing so AI always has continuity context
  Future<void> _ensurePassdownExists() async {
    try {
      final passdownPath = '${widget.project.path}${Platform.pathSeparator}PASSDOWN.md';
      final file = File(passdownPath);
      
      if (!await file.exists()) {
        // Create initial PASSDOWN.md
        final initialContent = '''# PASSDOWN.md - ${widget.project.name}

> **Purpose**: Living context document for session continuity and agent handoff.
> AI agents read this on session start to understand current state.
> Updated automatically on session close.

## Active Context

<!-- New entries will be added here automatically -->

## Archive

<!-- Completed entries move here -->
''';
        await file.writeAsString(initialContent);
        print('DEBUG: Created initial PASSDOWN.md');
      }
    } catch (e) {
      print('DEBUG: Failed to ensure PASSDOWN.md exists: $e');
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
    // Only save and stop session when window is actually closing (detached)
    // Do NOT stop on inactive (lost focus) or paused (minimized) - user may come back
    // The heartbeat mechanism handles crash detection instead
    if (widget.isInSeparateWindow && state == AppLifecycleState.detached) {
      print('DEBUG: Window detached - stopping session');
      stopSessionOnClose();
    }
  }
  
  /// Stop the active session when the chat window is closed
  /// Saves final state to file so main window can sync it
  /// Made public so it can be called from parent window before close
  
  /// Save session with both SESSION_NOTES.md and PASSDOWN.md in a SINGLE API call
  /// Called from _saveAndClose to minimize delay and API costs
  /// Returns true if successful
  Future<bool> saveSessionParallel() async {
    if (_messages.isEmpty) return true;
    
    // Skip if trivial session (fewer than 2 messages, no file operations)
    final hasFileOps = _messages.any((m) => m.fileUpdates.isNotEmpty);
    if (_messages.length < 2 && !hasFileOps) {
      print('DEBUG: Trivial session (${_messages.length} msgs, no file ops) - skipping summary API call');
      return true;
    }
    
    try {
      // Single API call that returns both SESSION_NOTES and PASSDOWN data
      final combinedData = await _generateSessionCloseData();
      
      if (combinedData != null) {
        final sessionSummary = combinedData['sessionNotes'] as Map<String, dynamic>?;
        final passdownEntry = combinedData['passdown'] as Map<String, dynamic>?;
        
        // Write both files in parallel (fast file I/O)
        await Future.wait([
          if (sessionSummary != null) _syncToSessionNotes(sessionSummary),
          if (passdownEntry != null) _syncToPassdown(passdownEntry),
        ]);
        
        // Save summary to session model
        if (sessionSummary != null) {
          await _saveSessionSummary(sessionSummary);
        }
        
        print('DEBUG: Single-call save complete - SESSION_NOTES: ${sessionSummary != null}, PASSDOWN: ${passdownEntry != null}');
      }
      return true;
    } catch (e) {
      print('DEBUG: Error during save: $e');
      return false;
    }
  }
  
  /// Generate both SESSION_NOTES and PASSDOWN data in a single API call
  /// This saves API costs (1 call instead of 2) and is faster
  Future<Map<String, dynamic>?> _generateSessionCloseData() async {
    final aiKeys = widget.isInSeparateWindow && widget.initialApiKeys != null
        ? widget.initialApiKeys!
        : ref.read(aiKeysProvider);
    
    if (!aiKeys.hasAnyKey) return null;
    
    final aiService = ref.read(aiServiceProvider);
    aiService.setAPIKeys(
      openAI: aiKeys.openAI,
      anthropic: aiKeys.anthropic,
      gemini: aiKeys.gemini,
    );
    
    // Build conversation text
    final conversationText = _messages.map((m) {
      return '${m.isUser ? "User" : "AI"}: ${m.content}';
    }).join('\n\n');
    
    // Get list of file operations
    final fileOps = <String>[];
    for (final msg in _messages) {
      if (msg.fileUpdates.isNotEmpty) {
        fileOps.addAll(msg.fileUpdates.keys);
      }
    }
    
    final filesStr = fileOps.isNotEmpty ? 'FILES MODIFIED: ${fileOps.join(", ")}' : '';
    final topicsStr = _sessionTopics.isNotEmpty 
        ? 'TOPICS DISCUSSED: ${_sessionTopics.map((t) => t.name).join(", ")}' 
        : '';
    
    // Combined prompt for both outputs
    final combinedPrompt = '''Analyze this session and provide TWO outputs: a session summary for notes, and a PASSDOWN handoff entry.

CONVERSATION:
$conversationText

$filesStr
$topicsStr

Respond with ONLY a JSON object (no markdown, no code blocks) in this EXACT format:
{
  "sessionNotes": {
    "title": "Brief session title (3-6 words)",
    "summary": "2-3 sentence summary of what was accomplished",
    "topics": ["topic1", "topic2"],
    "keyDecisions": ["Decision or outcome 1"],
    "filesModified": ["file1.dart"]
  },
  "passdown": {
    "workingOn": "Brief description of current task/focus",
    "status": "In Progress",
    "summary": "2-3 sentences for next agent",
    "nextSteps": ["Step 1", "Step 2"],
    "blockers": [],
    "context": "Additional context for continuity"
  }
}

For passdown.status use: "In Progress", "Blocked", or "Complete"''';

    try {
      final selectedProvider = ref.read(selectedAIProviderProvider);
      final selectedModel = ref.read(selectedModelProvider)[selectedProvider];
      
      final response = await aiService.sendMessage(
        provider: selectedProvider,
        model: selectedModel,
        message: combinedPrompt,
        conversationHistory: [],
        projectContext: {},
      );
      
      // Parse JSON from response
      var jsonStr = response.trim();
      if (jsonStr.contains('```')) {
        final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
        if (jsonMatch != null) {
          jsonStr = jsonMatch.group(1)?.trim() ?? jsonStr;
        }
      }
      
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: Failed to generate session close data: $e');
      // Return basic data if AI fails
      return {
        'sessionNotes': {
          'title': 'Session ${DateTime.now().toString().split(' ')[0]}',
          'summary': 'Session with ${_messages.length} messages.',
          'topics': _sessionTopics.map((t) => t.name).toList(),
          'keyDecisions': <String>[],
          'filesModified': fileOps,
        },
        'passdown': {
          'workingOn': 'Session work',
          'status': 'In Progress',
          'summary': 'Session with ${_messages.length} messages.',
          'nextSteps': <String>[],
          'blockers': <String>[],
          'context': '',
        },
      };
    }
  }

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
      
      // Note: PASSDOWN.md update is now done in saveSessionParallel()
      // Only call updatePassdown here if saveSessionParallel wasn't called first
      // (e.g., when window is closed via dispose without using Close & Save button)
      
      // Update session to completed with end time, conversation, and topics
      final updatedSession = activeSession.copyWith(
        status: SessionStatus.completed,
        endedAt: DateTime.now(),
        conversationHistory: _messages.map((m) => m.toJson()).toList(),
        topics: _sessionTopics,  // Save topics collected during session
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
      print('DEBUG: Auto-stopped session on window close (${_sessionTopics.length} topics saved)');
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

    if (activeSession.projectId.isNotEmpty) {
      setState(() {
        // Load conversation history
        _messages.clear();
        if (activeSession.conversationHistory.isNotEmpty) {
          _messages.addAll(
            activeSession.conversationHistory.map((json) => ChatMessage.fromJson(json)),
          );
        }
        
        // Load existing topics
        _sessionTopics.clear();
        _sessionTopics.addAll(activeSession.topics);
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

    // Update session with conversation history and topics
    final updatedSession = activeSession.copyWith(
      conversationHistory: _messages.map((m) => m.toJson()).toList(),
      topics: _sessionTopics,  // Include current topics
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
  
  /// Save AI-generated summary to the session model
  Future<void> _saveSessionSummary(Map<String, dynamic> summary) async {
    try {
      // Find active session
      final activeSession = widget.project.sessions.firstWhere(
        (s) => s.isActive,
        orElse: () => Session(projectId: '', title: ''),
      );
      
      if (activeSession.projectId.isEmpty) return;
      
      // Update topics from summary if AI found more
      final summaryTopics = List<String>.from(summary['topics'] ?? []);
      for (final topicName in summaryTopics) {
        if (!_sessionTopics.any((t) => t.name.toLowerCase() == topicName.toLowerCase())) {
          _sessionTopics.add(SessionTopic(
            name: topicName,
            isUserDefined: false,  // AI-generated
          ));
        }
      }
      
      // Update session with summary data
      final updatedSession = activeSession.copyWith(
        summary: summary['summary'] as String?,
        keyDecisions: List<String>.from(summary['keyDecisions'] ?? []),
        topics: _sessionTopics,
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
      
      // Save to file
      await _saveToFile(updatedProject);
      print('DEBUG: Saved session summary (${_sessionTopics.length} topics)');
    } catch (e) {
      print('DEBUG: Failed to save session summary: $e');
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
          // Update Passdown button
          IconButton(
            icon: const Icon(Icons.sync_alt),
            onPressed: _messages.isEmpty ? null : () => updatePassdown(forceUpdate: true),
            tooltip: 'Update PASSDOWN.md',
          ),
          // Update Session Notes button
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: _messages.isEmpty ? null : updateSessionNotes,
            tooltip: 'Update Session Notes',
          ),
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
                // Topic chips bar - shows current session topics
                if (_sessionTopics.isNotEmpty)
                  _buildTopicsBar(),
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
  
  /// Build a horizontal bar showing current session topics as chips
  /// Topics are informational labels - read-only, no delete option
  Widget _buildTopicsBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.label_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'Topics:',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sessionTopics.map((topic) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(
                      topic.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    // No delete button - topics are informational only
                    visualDensity: VisualDensity.compact,
                    backgroundColor: topic.isUserDefined
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Removed _removeTopic - topics are now read-only

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
    
    // Parse #topic: tags from the message
    final topicMatches = RegExp(r'#topic:\s*([^\s#]+)', caseSensitive: false).allMatches(message);
    for (final match in topicMatches) {
      final topicName = match.group(1)?.trim().toLowerCase();
      if (topicName != null && topicName.isNotEmpty) {
        // Only add if not already tracked
        if (!_sessionTopics.any((t) => t.name.toLowerCase() == topicName)) {
          _sessionTopics.add(SessionTopic(
            name: topicName,
            isUserDefined: true,
          ));
          _trackMilestone(topics: 1);  // Track topic addition
          print('DEBUG: Added user topic: $topicName');
        }
      }
    }
    
    // Track message milestone
    _trackMilestone(messages: 1);
    
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
      
      // Add PASSDOWN context for session continuity
      final passdownContext = await _readPassdownContext();
      if (passdownContext.isNotEmpty) {
        projectContext['[PASSDOWN]'] = passdownContext;
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
        
        // Track file operations milestone
        if (appliedUpdates.isNotEmpty) {
          _trackMilestone(fileOps: appliedUpdates.length);
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
  
  /// Update SESSION_NOTES.md with current session summary
  /// 
  /// [forceUpdate] - If true, always update (user clicked button). If false, use smart logic.
  /// [showSuccessMessage] - Show snackbar on success
  /// 
  /// Smart logic (when forceUpdate=false):
  /// - Always update if file operations occurred since last update
  /// - Always update if new topics added since last update  
  /// - If only messages changed, ask AI if the new content is meaningful
  Future<void> updateSessionNotes({bool showSuccessMessage = true, bool forceUpdate = true}) async {
    if (_messages.isEmpty) return;
    
    // Calculate what's new since last update
    final totalFileOps = _messages.fold<int>(0, (sum, m) => sum + m.fileUpdates.length);
    final newFileOps = totalFileOps - _fileOpsAtLastNotesUpdate;
    final newTopics = _sessionTopics.length - _topicsAtLastNotesUpdate;
    final newMessages = _messages.length - _messageCountAtLastNotesUpdate;
    
    // Smart update logic (when not forced)
    if (!forceUpdate && _messageCountAtLastNotesUpdate > 0) {
      // Hard-coded: Always update if file ops or new topics
      if (newFileOps > 0 || newTopics > 0) {
        print('DEBUG: Smart update - new file ops ($newFileOps) or topics ($newTopics), updating');
      } else if (newMessages > 0) {
        // Ask AI if the new messages are meaningful
        final shouldUpdate = await _askAIIfUpdateNeeded(newMessages);
        if (!shouldUpdate) {
          print('DEBUG: Smart update - AI says no meaningful changes, skipping');
          return;
        }
        print('DEBUG: Smart update - AI says meaningful changes, updating');
      } else {
        // No new activity at all
        print('DEBUG: Smart update - no new activity, skipping');
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get AI to summarize the session
      final summary = await _generateSessionSummary();
      
      if (summary != null) {
        // Update SESSION_NOTES.md file
        await _syncToSessionNotes(summary);
        
        // Also save summary to the session model
        await _saveSessionSummary(summary);
        
        // Reset milestone counters
        _fileOperationsSinceLastUpdate = 0;
        _messagesSinceLastUpdate = 0;
        _topicChangesSinceLastUpdate = 0;
        _hasPromptedForUpdate = false;
        _lastNotesUpdate = DateTime.now();
        
        if (showSuccessMessage && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session notes updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('DEBUG: Failed to update session notes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update notes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  /// Generate a summary of the current session using AI
  Future<Map<String, dynamic>?> _generateSessionSummary() async {
    final aiKeys = widget.isInSeparateWindow && widget.initialApiKeys != null
        ? widget.initialApiKeys!
        : ref.read(aiKeysProvider);
    
    if (!aiKeys.hasAnyKey) return null;
    
    final aiService = ref.read(aiServiceProvider);
    aiService.setAPIKeys(
      openAI: aiKeys.openAI,
      anthropic: aiKeys.anthropic,
      gemini: aiKeys.gemini,
    );
    
    // Build conversation text
    final conversationText = _messages.map((m) {
      return '${m.isUser ? "User" : "AI"}: ${m.content}';
    }).join('\n\n');
    
    // Get list of file operations
    final fileOps = <String>[];
    for (final msg in _messages) {
      if (msg.fileUpdates.isNotEmpty) {
        fileOps.addAll(msg.fileUpdates.keys);
      }
    }
    
    // Build summary prompt
    final summaryPrompt = '''Please analyze this session conversation and provide a structured summary.

CONVERSATION:
$conversationText

${fileOps.isNotEmpty ? 'FILES MODIFIED: ${fileOps.join(", ")}' : ''}

${_sessionTopics.isNotEmpty ? 'TOPICS DISCUSSED: ${_sessionTopics.map((t) => t.name).join(", ")}' : ''}

Respond with ONLY a JSON object (no markdown, no code blocks) in this exact format:
{
  "title": "Brief session title (3-6 words)",
  "summary": "2-3 sentence summary of what was accomplished",
  "topics": ["topic1", "topic2"],
  "keyDecisions": ["Decision or outcome 1", "Decision or outcome 2"],
  "filesModified": ["file1.dart", "file2.md"]
}''';

    try {
      final selectedProvider = ref.read(selectedAIProviderProvider);
      final selectedModel = ref.read(selectedModelProvider)[selectedProvider];
      
      final response = await aiService.sendMessage(
        provider: selectedProvider,
        model: selectedModel,
        message: summaryPrompt,
        conversationHistory: [],
        projectContext: {},
      );
      
      // Parse JSON from response
      // Try to extract JSON if wrapped in code blocks
      var jsonStr = response.trim();
      if (jsonStr.contains('```')) {
        final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
        if (jsonMatch != null) {
          jsonStr = jsonMatch.group(1)?.trim() ?? jsonStr;
        }
      }
      
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: Failed to generate summary: $e');
      // Return a basic summary if AI fails
      return {
        'title': 'Session ${DateTime.now().toString().split(' ')[0]}',
        'summary': 'Session with ${_messages.length} messages.',
        'topics': _sessionTopics.map((t) => t.name).toList(),
        'keyDecisions': [],
        'filesModified': _messages.expand((m) => m.fileUpdates.keys).toList(),
      };
    }
  }
  
  /// Sync session summary to SESSION_NOTES.md file
  /// Only writes if there's new activity since last update
  Future<void> _syncToSessionNotes(Map<String, dynamic> summary) async {
    // Skip if no new messages since last update
    if (_messages.length <= _messageCountAtLastNotesUpdate && _messageCountAtLastNotesUpdate > 0) {
      print('DEBUG: No new messages since last notes update (${_messages.length} <= $_messageCountAtLastNotesUpdate), skipping');
      return;
    }
    
    final sessionNotesPath = '${widget.project.path}${Platform.pathSeparator}SESSION_NOTES.md';
    final file = File(sessionNotesPath);
    
    // Find active session for metadata
    final activeSession = widget.project.sessions.firstWhere(
      (s) => s.isActive,
      orElse: () => Session(projectId: '', title: 'Unknown Session'),
    );
    
    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year}';
    final title = summary['title'] ?? activeSession.title;
    final summaryText = summary['summary'] ?? '';
    final topics = List<String>.from(summary['topics'] ?? []);
    final decisions = List<String>.from(summary['keyDecisions'] ?? []);
    final files = List<String>.from(summary['filesModified'] ?? []);
    
    // Build the session entry
    final entry = StringBuffer();
    entry.writeln('## ${activeSession.title}: $dateStr - $title ✅');
    entry.writeln();
    entry.writeln('### Summary');
    entry.writeln(summaryText);
    entry.writeln();
    
    if (topics.isNotEmpty) {
      entry.writeln('### Topics');
      for (final topic in topics) {
        entry.writeln('- $topic');
      }
      entry.writeln();
    }
    
    if (decisions.isNotEmpty) {
      entry.writeln('### Key Decisions');
      for (final decision in decisions) {
        entry.writeln('- $decision');
      }
      entry.writeln();
    }
    
    if (files.isNotEmpty) {
      entry.writeln('### Files Modified');
      for (final f in files) {
        entry.writeln('- `$f`');
      }
      entry.writeln();
    }
    
    entry.writeln('---');
    entry.writeln();
    
    // Read existing content or create new
    String existingContent = '';
    if (await file.exists()) {
      existingContent = await file.readAsString();
    }
    
    // Insert after header or create new file
    if (existingContent.isEmpty) {
      // Create new file with header
      final newContent = '''# Session Notes - ${widget.project.name}

${entry.toString()}''';
      await file.writeAsString(newContent);
    } else {
      // Find insertion point (after first heading)
      final lines = existingContent.split('\n');
      final insertIndex = lines.indexWhere((l) => l.startsWith('## '));
      
      if (insertIndex != -1) {
        // Insert before existing sessions
        lines.insert(insertIndex, entry.toString());
        await file.writeAsString(lines.join('\n'));
      } else {
        // No sessions yet, append after header
        await file.writeAsString('$existingContent\n${entry.toString()}');
      }
    }
    
    // Track when we last updated so we can use smart logic next time
    final totalFileOps = _messages.fold<int>(0, (sum, m) => sum + m.fileUpdates.length);
    _messageCountAtLastNotesUpdate = _messages.length;
    _fileOpsAtLastNotesUpdate = totalFileOps;
    _topicsAtLastNotesUpdate = _sessionTopics.length;
    print('DEBUG: Updated SESSION_NOTES.md for ${activeSession.title} (${_messages.length} msgs, $totalFileOps file ops, ${_sessionTopics.length} topics)');
  }
  
  /// Ask AI if the new messages contain meaningful progress worth updating notes
  Future<bool> _askAIIfUpdateNeeded(int newMessageCount) async {
    final aiKeys = widget.isInSeparateWindow && widget.initialApiKeys != null
        ? widget.initialApiKeys!
        : ref.read(aiKeysProvider);
    
    if (!aiKeys.hasAnyKey) return true;  // Default to update if no AI
    
    final aiService = ref.read(aiServiceProvider);
    aiService.setAPIKeys(
      openAI: aiKeys.openAI,
      anthropic: aiKeys.anthropic,
      gemini: aiKeys.gemini,
    );
    
    // Get the new messages since last update
    final startIndex = _messageCountAtLastNotesUpdate;
    final newMessages = _messages.sublist(startIndex).map((m) {
      return '${m.isUser ? "User" : "AI"}: ${m.content}';
    }).join('\n');
    
    final prompt = '''Analyze these recent messages from a development session and determine if they contain meaningful progress that should be documented in session notes.

NEW MESSAGES:
$newMessages

Meaningful progress includes:
- Decisions made
- Problems solved
- New features discussed or implemented
- Important information exchanged
- Technical discussions with substance

NOT meaningful (should skip):
- Casual greetings or farewells
- Small talk
- Simple acknowledgments like "ok", "thanks", "got it"
- Repetitive or redundant information

Respond with ONLY "yes" or "no" (lowercase, no punctuation).''';

    try {
      final selectedProvider = ref.read(selectedAIProviderProvider);
      final selectedModel = ref.read(selectedModelProvider)[selectedProvider];
      
      final response = await aiService.sendMessage(
        provider: selectedProvider,
        model: selectedModel,
        message: prompt,
        conversationHistory: [],
        projectContext: {},
      );
      
      final answer = response.trim().toLowerCase();
      print('DEBUG: AI meaningful check response: "$answer"');
      return answer.contains('yes');
    } catch (e) {
      print('DEBUG: AI meaningful check failed: $e');
      return true;  // Default to update on error
    }
  }
  
  String _monthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month];
  }
  
  /// Update PASSDOWN.md with current session context for continuity
  /// 
  /// PASSDOWN.md is the living context document that enables:
  /// - Single-agent continuity (pick up where you left off)
  /// - Multi-agent coordination (agent A hands off to agent B)
  /// - Session handoff with full context
  /// 
  /// [forceUpdate] - If true, always update. If false, use smart logic.
  Future<void> updatePassdown({bool forceUpdate = true}) async {
    if (_messages.isEmpty) return;
    
    // Use same smart logic as session notes
    final totalFileOps = _messages.fold<int>(0, (sum, m) => sum + m.fileUpdates.length);
    final newFileOps = totalFileOps - _fileOpsAtLastNotesUpdate;
    final newTopics = _sessionTopics.length - _topicsAtLastNotesUpdate;
    final newMessages = _messages.length - _messageCountAtLastNotesUpdate;
    
    if (!forceUpdate && _messageCountAtLastNotesUpdate > 0) {
      if (newFileOps <= 0 && newTopics <= 0 && newMessages <= 0) {
        print('DEBUG: PASSDOWN - no new activity, skipping');
        return;
      }
    }
    
    try {
      // Generate PASSDOWN entry using AI
      final passdownEntry = await _generatePassdownEntry();
      if (passdownEntry != null) {
        await _syncToPassdown(passdownEntry);
        print('DEBUG: PASSDOWN.md updated');
      }
    } catch (e) {
      print('DEBUG: Failed to update PASSDOWN: $e');
    }
  }
  
  /// Generate a PASSDOWN entry for the current session
  Future<Map<String, dynamic>?> _generatePassdownEntry() async {
    final aiKeys = widget.isInSeparateWindow && widget.initialApiKeys != null
        ? widget.initialApiKeys!
        : ref.read(aiKeysProvider);
    
    if (!aiKeys.hasAnyKey) return null;
    
    final aiService = ref.read(aiServiceProvider);
    aiService.setAPIKeys(
      openAI: aiKeys.openAI,
      anthropic: aiKeys.anthropic,
      gemini: aiKeys.gemini,
    );
    
    // Build conversation text (last 20 messages for context)
    final recentMessages = _messages.length > 20 
        ? _messages.sublist(_messages.length - 20) 
        : _messages;
    final convBuffer = StringBuffer();
    for (final m in recentMessages) {
      final role = m.isUser ? 'User' : 'AI';
      convBuffer.writeln('$role: ${m.content}\n');
    }
    
    // Get list of file operations
    final fileOps = <String>[];
    for (final msg in _messages) {
      if (msg.fileUpdates.isNotEmpty) {
        fileOps.addAll(msg.fileUpdates.keys);
      }
    }
    
    final topicsStr = _sessionTopics.isNotEmpty 
        ? 'TOPICS: ${_sessionTopics.map((t) => t.name).join(", ")}' 
        : '';
    final filesStr = fileOps.isNotEmpty 
        ? 'FILES MODIFIED: ${fileOps.join(", ")}' 
        : '';
    
    final passdownPrompt = '''Analyze this session and create a PASSDOWN entry for the next agent/session.

PASSDOWN is a handoff document that enables continuity. The next AI agent will read this to understand:
- What was being worked on
- Current status (In Progress, Blocked, Complete)
- What needs to happen next
- Any blockers or decisions pending

CONVERSATION:
${convBuffer.toString()}

$filesStr

$topicsStr

Respond with ONLY a JSON object (no markdown, no code blocks):
{
  "workingOn": "Brief description of current task/focus",
  "status": "In Progress" or "Blocked" or "Complete",
  "summary": "2-3 sentences of what was accomplished",
  "nextSteps": ["Step 1", "Step 2"],
  "blockers": ["Blocker if any, or empty array"],
  "keyDecisions": ["Important decisions made"],
  "filesModified": ["file1.dart", "file2.md"],
  "context": "Any additional context the next agent needs"
}''';

    try {
      final selectedProvider = ref.read(selectedAIProviderProvider);
      final selectedModel = ref.read(selectedModelProvider)[selectedProvider];
      
      final response = await aiService.sendMessage(
        provider: selectedProvider,
        model: selectedModel,
        message: passdownPrompt,
        conversationHistory: [],
        projectContext: {},
      );
      
      // Parse JSON from response
      var jsonStr = response.trim();
      if (jsonStr.contains('```')) {
        final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
        if (jsonMatch != null) {
          jsonStr = jsonMatch.group(1)?.trim() ?? jsonStr;
        }
      }
      
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: Failed to generate PASSDOWN entry: $e');
      // Return basic entry if AI fails
      return {
        'workingOn': 'Session work',
        'status': 'In Progress',
        'summary': 'Session with ${_messages.length} messages.',
        'nextSteps': <String>[],
        'blockers': <String>[],
        'keyDecisions': <String>[],
        'filesModified': fileOps,
        'context': '',
      };
    }
  }
  
  /// Sync PASSDOWN entry to PASSDOWN.md file
  /// New entries prepend to Active Context section
  /// Entries marked "Complete" move to Archive section
  Future<void> _syncToPassdown(Map<String, dynamic> entry) async {
    final passdownPath = '${widget.project.path}${Platform.pathSeparator}PASSDOWN.md';
    final file = File(passdownPath);
    
    // Find active session for metadata
    final activeSession = widget.project.sessions.firstWhere(
      (s) => s.isActive,
      orElse: () => Session(projectId: '', title: 'Unknown Session'),
    );
    
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final status = entry['status'] ?? 'In Progress';
    final workingOn = entry['workingOn'] ?? 'Session work';
    final summary = entry['summary'] ?? '';
    final nextSteps = List<String>.from(entry['nextSteps'] ?? []);
    final blockers = List<String>.from(entry['blockers'] ?? []);
    final keyDecisions = List<String>.from(entry['keyDecisions'] ?? []);
    final filesModified = List<String>.from(entry['filesModified'] ?? []);
    final contextStr = entry['context'] ?? '';
    
    // Build the PASSDOWN entry
    final entryBuffer = StringBuffer();
    entryBuffer.writeln('### [$timestamp] ${activeSession.title}');
    entryBuffer.writeln('**Status**: $status');
    entryBuffer.writeln('**Working On**: $workingOn');
    entryBuffer.writeln();
    entryBuffer.writeln(summary);
    entryBuffer.writeln();
    
    if (nextSteps.isNotEmpty) {
      entryBuffer.writeln('**Next Steps**:');
      for (final step in nextSteps) {
        entryBuffer.writeln('- $step');
      }
      entryBuffer.writeln();
    }
    
    if (blockers.isNotEmpty) {
      entryBuffer.writeln('**Blockers**:');
      for (final blocker in blockers) {
        entryBuffer.writeln('- ⚠️ $blocker');
      }
      entryBuffer.writeln();
    }
    
    if (keyDecisions.isNotEmpty) {
      entryBuffer.writeln('**Key Decisions**:');
      for (final decision in keyDecisions) {
        entryBuffer.writeln('- $decision');
      }
      entryBuffer.writeln();
    }
    
    if (filesModified.isNotEmpty) {
      entryBuffer.writeln('**Files Modified**:');
      for (final f in filesModified) {
        entryBuffer.writeln('- `$f`');
      }
      entryBuffer.writeln();
    }
    
    if (contextStr.isNotEmpty) {
      entryBuffer.writeln('**Context**: $contextStr');
      entryBuffer.writeln();
    }
    
    entryBuffer.writeln('---');
    entryBuffer.writeln();
    
    // Read existing content or create new file
    String existingContent = '';
    if (await file.exists()) {
      existingContent = await file.readAsString();
    }
    
    if (existingContent.isEmpty) {
      // Create new PASSDOWN.md
      final newContent = '''# PASSDOWN.md - ${widget.project.name}

> **Purpose**: Living context document for session continuity and agent handoff.
> AI agents read this on session start to understand current state.
> Updated automatically on session close.

## Active Context

${entryBuffer.toString()}

## Archive

<!-- Completed entries move here -->
''';
      await file.writeAsString(newContent);
    } else {
      // Insert new entry at top of Active Context section
      // Also move any "Complete" status entries to Archive
      final lines = existingContent.split('\n');
      final activeIndex = lines.indexWhere((l) => l.trim() == '## Active Context');
      final archiveIndex = lines.indexWhere((l) => l.trim() == '## Archive');
      
      if (activeIndex != -1) {
        // Find entries that are Complete and should be archived
        final activeSection = archiveIndex != -1 
            ? lines.sublist(activeIndex + 1, archiveIndex).join('\n')
            : lines.sublist(activeIndex + 1).join('\n');
        
        // Parse existing entries to find Complete ones
        final completedEntries = <String>[];
        final stillActiveEntries = <String>[];
        
        // Split by entry markers (### [timestamp])
        final entryPattern = RegExp(r'### \[\d{4}-\d{2}-\d{2}');
        final parts = activeSection.split(entryPattern);
        final matches = entryPattern.allMatches(activeSection).toList();
        
        for (int i = 0; i < matches.length; i++) {
          final entryContent = i < parts.length - 1 ? parts[i + 1] : '';
          final fullEntry = '${matches[i].group(0)}$entryContent';
          
          if (fullEntry.contains('**Status**: Complete')) {
            // Wrap in details tag for archive
            final titleMatch = RegExp(r'### \[([^\]]+)\] (.+)').firstMatch(fullEntry);
            final title = titleMatch != null 
                ? '[${titleMatch.group(1)}] ${titleMatch.group(2)}'
                : 'Completed Entry';
            completedEntries.add('<details>\n<summary>$title</summary>\n\n$fullEntry\n</details>\n');
          } else {
            stillActiveEntries.add(fullEntry);
          }
        }
        
        // Rebuild file
        final newLines = <String>[];
        newLines.addAll(lines.sublist(0, activeIndex + 1));
        newLines.add('');
        newLines.add(entryBuffer.toString());
        
        // Add still-active entries
        for (final active in stillActiveEntries) {
          newLines.add(active);
        }
        
        // Add archive section
        if (archiveIndex != -1) {
          newLines.add('');
          newLines.add('## Archive');
          newLines.add('');
          
          // Add newly completed entries
          for (final completed in completedEntries) {
            newLines.add(completed);
          }
          
          // Add existing archive content
          final existingArchive = lines.sublist(archiveIndex + 1).join('\n').trim();
          if (existingArchive.isNotEmpty && !existingArchive.startsWith('<!-- ')) {
            newLines.add(existingArchive);
          }
        }
        
        await file.writeAsString(newLines.join('\n'));
      } else {
        // No Active Context section, append to end
        await file.writeAsString('$existingContent\n${entryBuffer.toString()}');
      }
    }
    
    print('DEBUG: PASSDOWN.md synced for ${activeSession.title} (status: $status)');
  }
  
  /// Read PASSDOWN.md and return Active Context for system prompt injection
  Future<String> _readPassdownContext() async {
    try {
      final passdownPath = '${widget.project.path}${Platform.pathSeparator}PASSDOWN.md';
      final file = File(passdownPath);
      
      if (!await file.exists()) {
        return '';
      }
      
      final content = await file.readAsString();
      
      // Extract only Active Context section
      final activeMatch = RegExp(r'## Active Context\s*([\s\S]*?)(?=## Archive|$)').firstMatch(content);
      if (activeMatch != null) {
        final activeContext = activeMatch.group(1)?.trim() ?? '';
        if (activeContext.isNotEmpty) {
          return '\n\n📋 PASSDOWN (Session Continuity Context):\n$activeContext';
        }
      }
      
      return '';
    } catch (e) {
      print('DEBUG: Failed to read PASSDOWN: $e');
      return '';
    }
  }
  
  /// Check if we should prompt for a session notes update (AI milestone)
  void _checkMilestonePrompt() {
    // Don't prompt if we already have, or if recently updated
    if (_hasPromptedForUpdate) return;
    if (_lastNotesUpdate != null && 
        DateTime.now().difference(_lastNotesUpdate!).inMinutes < 10) return;
    
    // Prompt conditions:
    // - 5+ file operations since last update
    // - 15+ messages since last update  
    // - 3+ topic changes since last update
    final shouldPrompt = _fileOperationsSinceLastUpdate >= 5 ||
                        _messagesSinceLastUpdate >= 15 ||
                        _topicChangesSinceLastUpdate >= 3;
    
    if (shouldPrompt) {
      _hasPromptedForUpdate = true;
      _showMilestonePrompt();
    }
  }
  
  /// Show AI milestone prompt asking if user wants to update notes
  void _showMilestonePrompt() {
    // Add a system message suggesting update
    setState(() {
      _messages.add(ChatMessage(
        content: '📝 **Session Milestone Reached!**\n\n'
            'You\'ve made good progress! Would you like me to update the session notes?\n\n'
            '• ${_fileOperationsSinceLastUpdate} file(s) modified\n'
            '• ${_messagesSinceLastUpdate} messages exchanged\n'
            '• ${_topicChangesSinceLastUpdate} topic(s) discussed\n\n'
            'Click the **📝 Update Notes** button in the toolbar to save your progress.',
        isUser: false,
      ));
    });
    _scrollToBottom();
  }
  
  /// Track milestones after each significant action
  void _trackMilestone({int fileOps = 0, int messages = 0, int topics = 0}) {
    _fileOperationsSinceLastUpdate += fileOps;
    _messagesSinceLastUpdate += messages;
    _topicChangesSinceLastUpdate += topics;
    _checkMilestonePrompt();
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
