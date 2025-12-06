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
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

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
  State<MonacoEditor> createState() => MonacoEditorState();
}

class MonacoEditorState extends State<MonacoEditor> {
  late final WebviewController _controller;
  bool _isReady = false;
  bool _isDisposed = false;

  MonacoEditorState() {
    _controller = WebviewController();
    _logToFile('Monaco: State created, controller initialized');
  }

  // Expose controller and disposed state for emergency cleanup
  WebviewController get controller => _controller;
  bool get isDisposed => _isDisposed;
  bool get isReady => _isReady;
  void markDisposed() => _isDisposed = true;

  void _logToFile(String message) {
    try {
      final logFile = File('C:\\Users\\summo\\OneDrive\\Desktop\\crash_debug.log');
      logFile.writeAsStringSync('${DateTime.now()}: MONACO: $message\n', mode: FileMode.append, flush: true);
    } catch (e) {
      // Ignore
    }
  }

  @override
  void initState() {
    _logToFile('Monaco: initState called');
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    _logToFile('Monaco: _initializeWebView START');
    try {
      _logToFile('Monaco: Calling controller.initialize()');
      await _controller.initialize();
      _logToFile('Monaco: Controller initialized successfully');
      
      // Listen for messages from Monaco
      _logToFile('Monaco: Setting up webMessage listener');
      _controller.webMessage.listen((message) {
        _logToFile('Monaco: <<< Message received: "$message"');
        if (message == 'ready') {
          _logToFile('Monaco: Processing READY signal');
          setState(() => _isReady = true);
          _logToFile('Monaco: State set to ready');
          _setContent(widget.initialContent);
          _logToFile('Monaco: Initial content sent');
        } else if (message.startsWith('content:')) {
          _logToFile('Monaco: Content change received');
          final content = message.substring(8);
          widget.onChanged(content);
        } else {
          _logToFile('Monaco: Unknown message type: $message');
        }
      });
      _logToFile('Monaco: webMessage listener registered');

      // Load Monaco Editor HTML
      _logToFile('Monaco: About to load HTML content');
      await _controller.loadStringContent(_getMonacoHTML());
      _logToFile('Monaco: HTML content loaded successfully');
    } catch (e, stackTrace) {
      _logToFile('Monaco: WebView initialization ERROR: $e');
      _logToFile('Monaco: Stack trace: $stackTrace');
      print('Monaco: WebView initialization failed: $e');
      print('Stack trace: $stackTrace');
      // Try again after a short delay
      try {
        _logToFile('Monaco: Retrying after error');
        await Future.delayed(const Duration(milliseconds: 500));
        await _controller.initialize();
        await _controller.loadStringContent(_getMonacoHTML());
        _logToFile('Monaco: Retry successful');
      } catch (retryError, retryStack) {
        _logToFile('Monaco: Retry FAILED: $retryError');
        print('Monaco: Retry failed: $retryError');
        print('Stack trace: $retryStack');
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
            
            // Send content changes to Flutter (debounced to prevent crashes)
            let debounceTimer;
            editor.onDidChangeModelContent(() => {
                clearTimeout(debounceTimer);
                debounceTimer = setTimeout(() => {
                    try {
                        const content = editor.getValue();
                        window.chrome.webview.postMessage('content:' + content);
                    } catch (error) {
                        console.error('Failed to send content:', error);
                    }
                }, 300); // Wait 300ms after user stops typing
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

  /// Explicitly dispose WebView before window closes
  /// CRITICAL: Must be called BEFORE window closes to prevent crash
  Future<void> disposeWebView() async {
    _logToFile('=== START disposeWebView ===');
    
    if (_isDisposed) {
      _logToFile('Already disposed, skipping');
      print('Monaco: Already disposed, skipping');
      return;
    }
    _isDisposed = true;
    
    try {
      _logToFile('Setting _isDisposed = true');
      print('===== Monaco: START disposeWebView =====');
      print('Monaco: Controller hashCode: ${_controller.hashCode}');
      
      // Step 1: Suspend the WebView (graceful shutdown)
      _logToFile('About to call suspend()');
      print('Monaco: Calling suspend...');
      await _controller.suspend();
      
      _logToFile('suspend() completed');
      print('Monaco: Suspend completed');
      
      // Step 2: Wait briefly for suspend to complete
      _logToFile('Waiting 50ms');
      await Future.delayed(const Duration(milliseconds: 50));
      _logToFile('50ms wait done');
      
      // Step 3: DISPOSE CONTROLLER HERE (not in dispose()!)
      // This must happen while widget is still valid
      _logToFile('About to call controller.dispose()');
      print('Monaco: Calling controller.dispose()...');
      
      _controller.dispose();
      
      _logToFile('controller.dispose() returned');
      print('Monaco: Controller disposed');
      
      // Step 4: Wait for native cleanup
      _logToFile('Waiting 100ms for native cleanup');
      await Future.delayed(const Duration(milliseconds: 100));
      _logToFile('100ms wait done');
      
      _logToFile('=== END disposeWebView SUCCESS ===');
      print('===== Monaco: END disposeWebView (SUCCESS) =====');
    } catch (e, stack) {
      _logToFile('ERROR: $e');
      _logToFile('Stack: $stack');
      print('===== Monaco: ERROR during WebView disposal =====');
      print('Monaco: Error: $e');
      print('Monaco: Stack: $stack');
      print('===== Monaco: END disposeWebView (ERROR) =====');
    }
  }

  @override
  void dispose() {
    print('===== Monaco: Flutter dispose() called =====');
    print('Monaco: _isDisposed = $_isDisposed');
    
    // Controller should already be disposed in disposeWebView()
    // Only dispose here as fallback if disposeWebView() wasn't called
    if (!_isDisposed) {
      print('Monaco: WARNING - dispose() called without disposeWebView()!');
      print('Monaco: Disposing controller as fallback');
      try {
        _controller.dispose();
        print('Monaco: Fallback disposal successful');
      } catch (e) {
        print('Monaco: Fallback disposal error: $e');
      }
    } else {
      print('Monaco: Controller already disposed, skipping');
    }
    
    super.dispose();
    print('===== Monaco: Flutter dispose() END =====');
  }

  @override
  Widget build(BuildContext context) {
    _logToFile('Monaco: build() called, _isReady=$_isReady, _isDisposed=$_isDisposed');
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
