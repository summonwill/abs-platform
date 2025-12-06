/// ABS Platform - AI Service
/// 
/// Purpose: Multi-provider AI API client for OpenAI, Anthropic, and Google Gemini
/// Key Components:
///   - API key management for all three providers
///   - Message sending with conversation history
///   - Project context injection for governance-aware AI responses
///   - File update detection and parsing from AI responses
/// 
/// Dependencies:
///   - dio: HTTP client for API requests
/// 
/// Last Modified: December 5, 2025
library;

import 'package:dio/dio.dart';
import 'dart:convert';

enum AIProvider { openai, anthropic, gemini }

/// AI service for managing multi-provider AI API interactions
/// 
/// Handles API key storage, message routing, and response parsing
class AIService {
  final Dio _dio = Dio();
  
  String? _openAIKey;
  String? _anthropicKey;
  String? _geminiKey;

  /// Set API keys for one or more AI providers
  /// 
  /// Parameters:
  ///   - openAI: OpenAI API key (optional)
  ///   - anthropic: Anthropic API key (optional)
  ///   - gemini: Google Gemini API key (optional)
  /// 
  /// Side Effects: Stores keys in memory for subsequent API calls
  void setAPIKeys({String? openAI, String? anthropic, String? gemini}) {
    _openAIKey = openAI;
    _anthropicKey = anthropic;
    _geminiKey = gemini;
  }

  /// Send a message to the selected AI provider with project context
  /// 
  /// Parameters:
  ///   - model: Model identifier (uses provider default if null)
  ///   - provider: Which AI provider to use (openai/anthropic/gemini)
  ///   - message: User message to send
  ///   - conversationHistory: Previous messages in conversation
  ///   - projectContext: Governance files content for context injection
  ///   - fileTree: List of all files in project (optional)
  /// 
  /// Returns: AI response text
  /// 
  /// Throws: Exception if API key not configured or API call fails
  Future<String> sendMessage({
    String? model,
    required AIProvider provider,
    required String message,
    required List<Map<String, String>> conversationHistory,
    required Map<String, String> projectContext,
    List<String>? fileTree,
  }) async {
    switch (provider) {
      case AIProvider.openai:
        return await _sendToOpenAI(model ?? 'gpt-4o-mini', message, conversationHistory, projectContext, fileTree);
      case AIProvider.anthropic:
        return await _sendToAnthropic(model ?? 'claude-3-5-sonnet-20241022', message, conversationHistory, projectContext, fileTree);
      case AIProvider.gemini:
        return await _sendToGemini(model ?? 'gemini-2.0-flash-exp', message, conversationHistory, projectContext, fileTree);
    }
  }

  Future<String> _sendToOpenAI(
    String model,
    String message,
    List<Map<String, String>> history,
    Map<String, String> context,
    List<String>? fileTree,
  ) async {
    if (_openAIKey == null || _openAIKey!.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    // Build context message from governance files and file tree
    final contextMessage = _buildContextMessage(context, fileTree: fileTree);
    
    // DEBUG: Log what we're sending
    print('DEBUG _sendToOpenAI:');
    print('  Context keys: ${context.keys.toList()}');
    print('  FileTree count: ${fileTree?.length ?? 0}');
    print('  Context message length: ${contextMessage.length}');
    if (context.containsKey('TODO.md')) {
      print('  TODO.md first 100 chars: ${context['TODO.md']?.substring(0, 100)}');
    }

    final messages = [
      {
        'role': 'system',
        'content': 'You are an AI assistant helping with project management using the AI Bootstrap System (ABS). '
            'The user has provided their project governance files and file structure. Help them manage their project, update TODO items, '
            'maintain session notes, and work with any project files.\n\n'
            'FILE OPERATIONS: You can create, update, or delete any project file using this format:\n'
            '=== CREATE: path/to/file.ext ===\n'
            'file content here\n'
            '\n'
            '=== UPDATE: path/to/existing.ext ===\n'
            'updated content\n'
            '\n'
            '=== DELETE: path/to/file.ext ===\n'
            '\n'
            'For governance files (TODO.md, SESSION_NOTES.md, etc), you can use the legacy format: === FILENAME.md ===\n\n'
            'If asked about specific files you haven\'t seen yet, ask the user if they\'d like you to read them.'
      },
      if (contextMessage.isNotEmpty) {
        'role': 'system',
        'content': contextMessage,
      },
      ...history,
      {'role': 'user', 'content': message},
    ];

    try {
      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_openAIKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'messages': messages,
          'temperature': 0.7,
        },
      );

      return response.data['choices'][0]['message']['content'];
    } catch (e) {
      if (e is DioException && e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('error')) {
          final errorMsg = errorData['error']['message'] ?? errorData['error'].toString();
          throw Exception('OpenAI API error: $errorMsg');
        }
      }
      throw Exception('OpenAI API error: $e');
    }
  }

  Future<String> _sendToAnthropic(
    String model,
    String message,
    List<Map<String, String>> history,
    Map<String, String> context,
    List<String>? fileTree,
  ) async {
    if (_anthropicKey == null || _anthropicKey!.isEmpty) {
      throw Exception('Anthropic API key not configured');
    }

    final contextMessage = _buildContextMessage(context, fileTree: fileTree);

    final messages = [
      ...history,
      {'role': 'user', 'content': message},
    ];

    try {
      final response = await _dio.post(
        'https://api.anthropic.com/v1/messages',
        options: Options(
          headers: {
            'x-api-key': _anthropicKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'max_tokens': 4096,
          'system': 'You are an AI assistant helping with project management using the AI Bootstrap System (ABS). '
              'The user has provided their project governance files and file structure. Help them manage their project, update TODO items, '
              'maintain session notes, and work with any project files.\n\n'
              'FILE OPERATIONS: You can create, update, or delete any project file using this format:\n'
              '=== CREATE: path/to/file.ext ===\n'
              'file content here\n'
              '\n'
              '=== UPDATE: path/to/existing.ext ===\n'
              'updated content\n'
              '\n'
              '=== DELETE: path/to/file.ext ===\n'
              '\n'
              'For governance files (TODO.md, SESSION_NOTES.md, etc), you can use the legacy format: === FILENAME.md ===\n\n'
              'If asked about specific files you haven\'t seen yet, ask the user if they\'d like you to read them.\n\n$contextMessage',
          'messages': messages,
        },
      );

      return response.data['content'][0]['text'];
    } catch (e) {
      throw Exception('Anthropic API error: $e');
    }
  }

  Future<String> _sendToGemini(
    String model,
    String message,
    List<Map<String, String>> history,
    Map<String, String> context,
    List<String>? fileTree,
  ) async {
    if (_geminiKey == null || _geminiKey!.isEmpty) {
      throw Exception('Gemini API key not configured');
    }

    final contextMessage = _buildContextMessage(context, fileTree: fileTree);

    final contents = [
      {
        'role': 'user',
        'parts': [
          {
            'text': 'System: You are an AI assistant helping with project management using the AI Bootstrap System (ABS). '
                'The user has provided their project governance files and file structure. Help them manage their project, update TODO items, '
                'maintain session notes, and work with any project files.\n\n'
                'FILE OPERATIONS: You can create, update, or delete any project file using this format:\n'
                '=== CREATE: path/to/file.ext ===\n'
                'file content here\n'
                '\n'
                '=== UPDATE: path/to/existing.ext ===\n'
                'updated content\n'
                '\n'
                '=== DELETE: path/to/file.ext ===\n'
                '\n'
                'For governance files (TODO.md, SESSION_NOTES.md, etc), you can use the legacy format: === FILENAME.md ===\n\n'
                'If asked about specific files you haven\'t seen yet, ask the user if they\'d like you to read them.\n\n$contextMessage'
          }
        ]
      },
      for (var msg in history)
        {
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg['content']}
          ]
        },
      {
        'role': 'user',
        'parts': [
          {'text': message}
        ]
      },
    ];

    try {
      final response = await _dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiKey',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
        data: {'contents': contents},
      );

      return response.data['candidates'][0]['content']['parts'][0]['text'];
    } catch (e) {
      throw Exception('Gemini API error: $e');
    }
  }

  String _buildContextMessage(Map<String, String> context, {List<String>? fileTree}) {
    if (context.isEmpty && (fileTree == null || fileTree.isEmpty)) return '';

    final buffer = StringBuffer();
    
    // Add file tree if available
    if (fileTree != null && fileTree.isNotEmpty) {
      buffer.writeln('Project File Structure:');
      buffer.writeln('```');
      for (final file in fileTree) {
        buffer.writeln(file);
      }
      buffer.writeln('```');
      buffer.writeln('\nNote: You can ask me to read any of these files if you need to see their contents.');
      buffer.writeln('\n---\n');
    }
    
    // Add governance files
    if (context.isNotEmpty) {
      buffer.writeln('Project Governance Files:\n');
      
      for (var entry in context.entries) {
        buffer.writeln('=== ${entry.key} ===');
        buffer.writeln(entry.value);
        buffer.writeln('\n---\n');
      }
    }

    return buffer.toString();
  }

  /// Parse file operations from AI response
  /// 
  /// Supports multiple operation types:
  /// - CREATE: === CREATE: path/to/file.ext ===
  /// - UPDATE: === UPDATE: path/to/file.ext ===
  /// - DELETE: === DELETE: path/to/file.ext ===
  /// - Legacy governance file format: === FILENAME.md ===
  /// 
  /// Returns: Map of operations { 'operation:path': content or '' }
  Map<String, String> parseFileUpdates(String aiResponse) {
    final updates = <String, String>{};
    
    // Pattern for new format: === OPERATION: filepath ===
    // More flexible - can appear anywhere in the response
    final operationPattern = RegExp(
      r'===\s*(CREATE|UPDATE|DELETE):\s*([^\n]+?)\s*===\s*\n([\s\S]*?)(?=\n===|---|\Z)',
      caseSensitive: false,
      multiLine: true,
    );
    
    final operationMatches = operationPattern.allMatches(aiResponse);
    for (var match in operationMatches) {
      final operation = match.group(1)!.toUpperCase();
      final filepath = match.group(2)!.trim();
      final content = match.group(3)?.trim() ?? '';
      updates['$operation:$filepath'] = content;
    }
    
    // Pattern to match legacy governance file format
    // Looking for: === FILENAME.md === followed by content
    final filePattern = RegExp(
      r'===\s*([A-Z_]+\.md)\s*===\s*\n([\s\S]*?)(?=\n===|\Z)',
      caseSensitive: false,
    );

    final matches = filePattern.allMatches(aiResponse);
    for (var match in matches) {
      final fileName = match.group(1)?.trim();
      final content = match.group(2)?.trim();
      
      if (fileName != null && content != null && content.isNotEmpty) {
        updates[fileName] = content;
      }
    }

    return updates;
  }
}
