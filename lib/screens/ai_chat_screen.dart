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
/// Last Modified: December 5, 2025
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../services/ai_service.dart';
import '../providers/ai_provider.dart';
import '../providers/project_provider.dart';

/// AI chat screen with conversation history and context awareness
class AIChatScreen extends ConsumerStatefulWidget {
  final Project project;

  const AIChatScreen({super.key, required this.project});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConversationHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load conversation history from active session
  /// 
  /// Finds the active session in the project and populates
  /// the messages list with previous conversation.
  /// 
  /// Side Effects:
  ///   - Clears current messages
  ///   - Populates _messages from session.conversationHistory
  ///   - Scrolls to bottom after loading
  void _loadConversationHistory() {
    // Load conversation from active session if exists
    final activeSession = widget.project.sessions.firstWhere(
      (s) => s.isActive,
      orElse: () => Session(projectId: '', title: ''),
    );

    if (activeSession.projectId.isNotEmpty) {
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

  /// Save current conversation to active session
  /// 
  /// Persists the messages list to the active session's
  /// conversationHistory field and updates the project.
  /// 
  /// Side Effects:
  ///   - Updates session in project sessions list
  ///   - Saves project to Hive via ProjectsNotifier
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

    await ref.read(projectsProvider.notifier).updateProject(updatedProject);
    
    // Update selected project
    ref.read(selectedProjectProvider.notifier).state = updatedProject;
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
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
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
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

    _messageController.clear();
    
    setState(() {
      _messages.add(ChatMessage(content: message, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final aiService = ref.read(aiServiceProvider);
      final aiKeys = ref.read(aiKeysProvider);
      final selectedProvider = ref.read(selectedAIProviderProvider);

      // Set API keys
      aiService.setAPIKeys(
        openAI: aiKeys.openAI,
        anthropic: aiKeys.anthropic,
        gemini: aiKeys.gemini,
      );

      // Get project context with file tree
      // Note: In separate windows, we need to read files directly since Hive is locked by main window
      final fileService = ref.read(fileServiceProvider);
      final fullProjectData = await fileService.exportFullProjectForAI(widget.project.path);
      
      final projectContext = fullProjectData['governanceFiles'] as Map<String, String>? ?? {};
      final fileTree = fullProjectData['fileTree'] as List<String>? ?? [];

      // DEBUG: Check what we're sending
      print("DEBUG Project Context:");
      print("  Project Path: ${widget.project.path}");
      print("  Governance Files: ${projectContext.keys.toList()}");
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

      // Apply updates to files
      if (updates.isNotEmpty) {
        for (var entry in updates.entries) {
          await ref.read(fileServiceProvider).writeGovernanceFile(
                widget.project.path,
                entry.key,
                entry.value,
              );
        }
      }

      setState(() {
        _messages.add(ChatMessage(
          content: response,
          isUser: false,
          fileUpdates: updates,
        ));
        _isLoading = false;
      });

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
