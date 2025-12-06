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
  }) async {
    switch (provider) {
      case AIProvider.openai:
        return await _sendToOpenAI(model ?? 'gpt-4o-mini', message, conversationHistory, projectContext);
      case AIProvider.anthropic:
        return await _sendToAnthropic(model ?? 'claude-3-5-sonnet-20241022', message, conversationHistory, projectContext);
      case AIProvider.gemini:
        return await _sendToGemini(model ?? 'gemini-2.0-flash-exp', message, conversationHistory, projectContext);
    }
  }

  Future<String> _sendToOpenAI(
    String model,
    String message,
    List<Map<String, String>> history,
    Map<String, String> context,
  ) async {
    if (_openAIKey == null || _openAIKey!.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    // Build context message from governance files
    final contextMessage = _buildContextMessage(context);

    final messages = [
      {
        'role': 'system',
        'content': 'You are an AI assistant helping with project management using the AI Bootstrap System (ABS). '
            'The user has provided their project governance files. Help them manage their project, update TODO items, '
            'and maintain session notes. When updating files, use clear markdown sections.'
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
  ) async {
    if (_anthropicKey == null || _anthropicKey!.isEmpty) {
      throw Exception('Anthropic API key not configured');
    }

    final contextMessage = _buildContextMessage(context);

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
              'The user has provided their project governance files. Help them manage their project, update TODO items, '
              'and maintain session notes. When updating files, use clear markdown sections.\n\n$contextMessage',
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
  ) async {
    if (_geminiKey == null || _geminiKey!.isEmpty) {
      throw Exception('Gemini API key not configured');
    }

    final contextMessage = _buildContextMessage(context);

    final contents = [
      {
        'role': 'user',
        'parts': [
          {
            'text': 'System: You are an AI assistant helping with project management using the AI Bootstrap System (ABS). '
                'The user has provided their project governance files. Help them manage their project, update TODO items, '
                'and maintain session notes. When updating files, use clear markdown sections.\n\n$contextMessage'
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

  String _buildContextMessage(Map<String, String> context) {
    if (context.isEmpty) return '';

    final buffer = StringBuffer('Project Governance Files:\n\n');
    
    for (var entry in context.entries) {
      buffer.writeln('=== ${entry.key} ===');
      buffer.writeln(entry.value);
      buffer.writeln('\n---\n');
    }

    return buffer.toString();
  }

  Map<String, String> parseFileUpdates(String aiResponse) {
    final updates = <String, String>{};
    
    // Pattern to match file updates in AI response
    // Looking for: === FILENAME === followed by content
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
