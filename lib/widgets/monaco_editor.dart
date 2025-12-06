/// ABS Platform - Monaco Editor Widget
/// 
/// Purpose: High-performance web-based code editor using Monaco (VS Code's editor)
/// Key Components:
///   - WebView integration for Windows
///   - Monaco Editor CDN loading
///   - Bidirectional text sync (Flutter <-> Monaco)
///   - Change detection for save button
/// 
/// Dependencies:
///   - webview_windows: Native WebView for Windows
/// 
/// Performance: Handles files with 10,000+ lines smoothly
/// 
/// Last Modified: December 5, 2025

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:convert';
import '../services/debug_logger.dart';

/// Monaco Editor widget with full editing capabilities
/// 
/// Uses VS Code's Monaco Editor via WebView for instant performance
/// on large files (1000+ lines)
class MonacoEditor extends StatefulWidget {
  final String initialContent;
  final String language;
  final ValueChanged<String> onChanged;

  const MonacoEditor({
    super.key,
    required this.initialContent,
    this.language = 'markdown',
    required this.onChanged,
  });

  @override
  State<MonacoEditor> createState() => _MonacoEditorState();
}

class _MonacoEditorState extends State<MonacoEditor> {
  final _controller = WebviewController();
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      await DebugLogger.log('Monaco: Starting WebView initialization');
      await _controller.initialize();
      await DebugLogger.log('Monaco: WebView initialized successfully');
      
      // Listen for messages from Monaco
      _controller.webMessage.listen((message) async {
        await DebugLogger.log('Monaco: Received message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...');
        if (message == 'ready') {
          await DebugLogger.log('Monaco: Editor ready, setting initial content');
          setState(() => _isReady = true);
          _setContent(widget.initialContent);
        } else if (message.startsWith('content:')) {
          final content = message.substring(8);
          widget.onChanged(content);
        }
      }, onError: (error) async {
        await DebugLogger.error('Monaco: WebMessage stream error', error);
      });

      // Load Monaco Editor HTML
      await DebugLogger.log('Monaco: Loading HTML content');
      await _controller.loadStringContent(_getMonacoHTML());
      await DebugLogger.log('Monaco: HTML content loaded');
    } catch (e, stackTrace) {
      await DebugLogger.error('Monaco: WebView initialization failed', e, stackTrace);
      // Try again after a short delay
      try {
        await DebugLogger.log('Monaco: Retrying initialization after delay');
        await Future.delayed(const Duration(milliseconds: 500));
        await _controller.initialize();
        await _controller.loadStringContent(_getMonacoHTML());
        await DebugLogger.log('Monaco: Retry successful');
      } catch (retryError, retryStack) {
        await DebugLogger.error('Monaco: Retry failed', retryError, retryStack);
      }
    }
  }

  Future<void> _setContent(String content) async {
    if (!_isReady) return;
    
    final escapedContent = json.encode(content);
    await _controller.executeScript('setContent($escapedContent)');
  }

  String _getMonacoHTML() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            margin: 0;
            padding: 0;
            overflow: hidden;
        }
        #container {
            width: 100vw;
            height: 100vh;
        }
    </style>
</head>
<body>
    <div id="container"></div>
    
    <script src="https://unpkg.com/monaco-editor@0.45.0/min/vs/loader.js"></script>
    <script>
        require.config({ paths: { vs: 'https://unpkg.com/monaco-editor@0.45.0/min/vs' } });
        
        let editor;
        
        require(['vs/editor/editor.main'], function() {
            editor = monaco.editor.create(document.getElementById('container'), {
                value: '',
                language: '${widget.language}',
                theme: 'vs-dark',
                automaticLayout: true,
                fontSize: 13,
                fontFamily: 'Consolas, monospace',
                lineNumbers: 'on',
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                wordWrap: 'off',
                renderWhitespace: 'selection'
            });
            
            // Notify Flutter that editor is ready
            window.chrome.webview.postMessage('ready');
            
            // Send content changes to Flutter
            editor.onDidChangeModelContent(() => {
                const content = editor.getValue();
                window.chrome.webview.postMessage('content:' + content);
            });
        });
        
        function setContent(content) {
            if (editor) {
                editor.setValue(content);
            }
        }
    </script>
</body>
</html>
''';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Webview(_controller),
        if (!_isReady)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Monaco Editor...'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
