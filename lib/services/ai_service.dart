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
        'content': '''You are an AI assistant helping with project management using the AI Bootstrap System (ABS).
The user has provided their project governance files, file structure, and relevant file contents. Help them manage their project.

📋 PASSDOWN CONTEXT:
If you see [PASSDOWN] in your context, this contains the active handoff information from previous sessions.
- Read PASSDOWN to understand what was being worked on
- Use it to maintain continuity across sessions
- Reference it when you're uncertain about project state or history

🔴 IMPORTANT: ONLY perform file operations when the user EXPLICITLY asks you to create, update, delete, add, modify, or remove a file or folder. 
- If the user is just chatting or asking questions, respond conversationally WITHOUT any file operations.
- Do NOT assume the user wants file changes unless they clearly state it.

🔴 MANDATORY FILE/FOLDER OPERATION FORMAT 🔴
When the user EXPLICITLY asks you to CREATE, UPDATE, or DELETE a file or folder, you MUST use this EXACT format:

FOR CREATING FILES:
=== CREATE: path/to/filename.ext ===
(file content goes here)

FOR CREATING FOLDERS (trailing slash):
=== CREATE: path/to/foldername/ ===

FOR UPDATING FILES:
=== UPDATE: path/to/filename.ext ===
(COMPLETE file content with your modifications integrated)

FOR DELETING FILES:
=== DELETE: path/to/filename.ext ===

FOR DELETING FOLDERS (trailing slash):
=== DELETE: path/to/foldername/ ===

⚠️ CRITICAL FOR UPDATES:
- You will see file contents in the context labeled as [FILE] path/to/file
- When updating, include the ENTIRE file content with your changes integrated
- The system REPLACES the whole file - do NOT just show changes
- Preserve ALL existing content unless the user specifically asks to remove something

RULES:
1. Start with === marker for file operations (no text before it)
2. Use the FULL path relative to project root
3. Use trailing slash (/) for folders
4. For UPDATE, include COMPLETE file with changes merged in
5. Add explanation after --- separator
6. ONLY do file operations when explicitly requested by the user

You have FULL access to read, write, modify, and delete ANY file or folder in the project directory and all subdirectories.'''
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

      final responseText = response.data['choices'][0]['message']['content'] as String;
      
      // DEBUG: Log the raw AI response for troubleshooting
      print('DEBUG _sendToOpenAI - RAW RESPONSE:');
      print('  Response length: ${responseText.length}');
      print('  First 500 chars: ${responseText.substring(0, responseText.length < 500 ? responseText.length : 500)}');
      print('  Contains === CREATE: ${responseText.contains('=== CREATE:')}');
      print('  Contains === UPDATE: ${responseText.contains('=== UPDATE:')}');
      print('  Contains === DELETE: ${responseText.contains('=== DELETE:')}');
      
      return responseText;
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
              'The user has provided their project governance files, file structure, and relevant file contents.\n\n'
              'PASSDOWN CONTEXT: If you see [PASSDOWN] in your context, this contains handoff information from previous sessions. '
              'Use it to understand what was being worked on and maintain continuity.\n\n'
              'IMPORTANT: ONLY perform file operations when the user EXPLICITLY asks you to create, update, modify, or delete files.\n'
              '- Casual conversation does NOT require file operations\n'
              '- Questions about the project do NOT require file operations\n'
              '- Only use === CREATE/UPDATE/DELETE === when the user clearly requests a file change\n\n'
              'FILE/FOLDER OPERATIONS - Use this EXACT format (only when explicitly requested):\n\n'
              'CREATE file: === CREATE: path/to/file.ext ===\\n(content)\n'
              'CREATE folder: === CREATE: path/to/folder/ ===\n'
              'UPDATE file: === UPDATE: path/to/file.ext ===\\n(COMPLETE content with changes)\n'
              'DELETE file: === DELETE: path/to/file.ext ===\n'
              'DELETE folder: === DELETE: path/to/folder/ ===\n\n'
              'CRITICAL: For UPDATE, include the ENTIRE file with your modifications. System REPLACES the whole file.\n'
              'File contents appear as [FILE] path/to/file in context. Use trailing slash for folders.\n'
              'You have FULL access to all files in the project.\n\n$contextMessage',
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
                'The user has provided their project governance files, file structure, and relevant file contents.\n\n'
                'PASSDOWN CONTEXT: If you see [PASSDOWN] in your context, this contains handoff information from previous sessions. '
                'Use it to understand what was being worked on and maintain continuity.\n\n'
                'IMPORTANT: ONLY perform file operations when the user EXPLICITLY asks you to create, update, modify, or delete files.\n'
                '- Casual conversation does NOT require file operations\n'
                '- Questions about the project do NOT require file operations\n'
                '- Only use === CREATE/UPDATE/DELETE === when the user clearly requests a file change\n\n'
                'FILE/FOLDER OPERATIONS - Use this EXACT format (only when explicitly requested):\n\n'
                'CREATE file: === CREATE: path/to/file.ext ===\\n(content)\n'
                'CREATE folder: === CREATE: path/to/folder/ ===\n'
                'UPDATE file: === UPDATE: path/to/file.ext ===\\n(COMPLETE content with changes)\n'
                'DELETE file: === DELETE: path/to/file.ext ===\n'
                'DELETE folder: === DELETE: path/to/folder/ ===\n\n'
                'CRITICAL: For UPDATE, include the ENTIRE file with your modifications. System REPLACES the whole file.\n'
                'File contents appear as [FILE] path/to/file in context. Use trailing slash for folders.\n'
                'You have FULL access to all files in the project.\n\n$contextMessage'
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
    
    // DEBUG: Log the response being parsed
    print('DEBUG parseFileUpdates:');
    print('  Response length: ${aiResponse.length}');
    print('  First 300 chars: ${aiResponse.substring(0, aiResponse.length < 300 ? aiResponse.length : 300)}');
    
    // First, extract folder creation operations (paths ending in /)
    // These have no content and should be processed separately
    final folderPattern = RegExp(
      r'===\s*CREATE:\s*([^\r\n]+?/)\s*===',
      caseSensitive: false,
      multiLine: true,
    );
    
    final folderMatches = folderPattern.allMatches(aiResponse);
    print('  Folder CREATE matches found: ${folderMatches.length}');
    
    for (var match in folderMatches) {
      final filepath = match.group(1)!.trim();
      print('  Found: CREATE:$filepath (folder)');
      updates['CREATE:$filepath'] = '';
    }
    
    // Pattern for CREATE/UPDATE operations (require content after)
    // Only match files (paths NOT ending in /)
    // Captures content until: next === marker at start of line, --- at start of line, or end of string
    // Handles both \r\n (Windows) and \n (Unix) line endings
    final createUpdatePattern = RegExp(
      r'===\s*(CREATE|UPDATE):\s*([^\r\n/]+?(?:\.[a-zA-Z0-9]+))\s*===\s*\r?\n([\s\S]*?)(?=\r?\n===|\r?\n---)',
      caseSensitive: false,
      multiLine: true,
    );
    
    var createUpdateMatches = createUpdatePattern.allMatches(aiResponse).toList();
    
    // If no matches with separator, try matching to end of string (for responses without --- separator)
    if (createUpdateMatches.isEmpty) {
      final endOfStringPattern = RegExp(
        r'===\s*(CREATE|UPDATE):\s*([^\r\n]+?(?:\.[a-zA-Z0-9]+))\s*===\s*\r?\n([\s\S]+)',
        caseSensitive: false,
        multiLine: true,
      );
      createUpdateMatches = endOfStringPattern.allMatches(aiResponse).toList();
      if (createUpdateMatches.isNotEmpty) {
        print('  (Used fallback end-of-string pattern)');
      }
    }
    
    print('  CREATE/UPDATE matches found: ${createUpdateMatches.length}');
    
    for (var match in createUpdateMatches) {
      final operation = match.group(1)!.toUpperCase();
      final filepath = match.group(2)!.trim();
      var rawContent = match.group(3) ?? '';
      var content = rawContent.trim();
      
      // DEBUG: Show raw vs trimmed
      print('  Raw content length: ${rawContent.length}, Trimmed: ${content.length}');
      print('  Raw content repr: ${rawContent.replaceAll('\n', '\\n').replaceAll('\r', '\\r')}');
      
      // Remove === END === marker if present
      content = content.replaceAll(RegExp(r'\s*===\s*END\s*===\s*$', caseSensitive: false), '').trim();
      
      // Remove --- separator and any AI explanation text after it
      // The AI often adds "---" followed by an explanation of what it did
      final dashSeparatorIndex = content.indexOf(RegExp(r'\r?\n---\s*\r?\n'));
      if (dashSeparatorIndex != -1) {
        content = content.substring(0, dashSeparatorIndex).trim();
        print('  Stripped AI explanation after --- separator');
      }
      
      print('  Found: $operation:$filepath (content: ${content.length} chars)');
      updates['$operation:$filepath'] = content;
    }
    
    // Separate pattern for DELETE operations (no content required)
    final deletePattern = RegExp(
      r'===\s*DELETE:\s*([^\n=]+?)\s*===',
      caseSensitive: false,
      multiLine: true,
    );
    
    final deleteMatches = deletePattern.allMatches(aiResponse);
    print('  DELETE matches found: ${deleteMatches.length}');
    
    for (var match in deleteMatches) {
      final filepath = match.group(1)!.trim();
      print('  Found: DELETE:$filepath');
      updates['DELETE:$filepath'] = '';
    }
    
    // Pattern to match legacy governance file format
    // Looking for: === FILENAME.md === followed by content
    final filePattern = RegExp(
      r'===\s*([A-Z_]+\.md)\s*===\s*\n([\s\S]*?)(?=\n===|\Z)',
      caseSensitive: false,
    );

    final matches = filePattern.allMatches(aiResponse);
    print('  Legacy format matches: ${matches.length}');
    
    for (var match in matches) {
      final fileName = match.group(1)?.trim();
      final content = match.group(2)?.trim();
      
      if (fileName != null && content != null && content.isNotEmpty) {
        print('  Found legacy: $fileName (content: ${content.length} chars)');
        updates[fileName] = content;
      }
    }

    print('  Total updates: ${updates.length}');
    return updates;
  }
}
