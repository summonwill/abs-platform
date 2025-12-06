/// ABS Platform - File Editor Window (Separate OS Window)
/// 
/// Purpose: Entry point for separate file editor windows spawned via desktop_multi_window
/// Key Components:
///   - Window initialization and Hive setup
///   - re_editor integration (native Flutter code editor)
///   - File save functionality with modified indicator
///   - Custom scroll controllers for optimized selection performance
///   - File data reconstruction from JSON arguments
/// 
/// Dependencies:
///   - desktop_multi_window: Multi-window infrastructure (separate processes)
///   - hive_flutter: Storage access in separate window
///   - re_editor: Native Flutter code editor (WebView-free)
/// 
/// Technical Notes:
///   - Uses re_editor instead of Monaco/WebView due to multi-window incompatibility
///   - desktop_multi_window creates separate PROCESSES - WebView crashes on close
///   - Native Flutter widgets (re_editor, TextField) work perfectly
/// 
/// Last Modified: December 6, 2025
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:re_editor/re_editor.dart';
import '../services/file_service.dart';

/// Separate window for file editing
/// 
/// StatefulWidget to handle async Hive initialization before rendering
class FileEditorWindow extends StatefulWidget {
  final WindowController controller;
  final Map<String, dynamic> args;

  const FileEditorWindow({
    super.key,
    required this.controller,
    required this.args,
  });

  @override
  State<FileEditorWindow> createState() => _FileEditorWindowState();
}

class _FileEditorWindowState extends State<FileEditorWindow> with WidgetsBindingObserver {
  bool _isInitialized = false;
  late String _fileName;
  late String _projectPath;
  late String _content;
  late String _currentContent;
  bool _isModified = false;
  bool _isSaving = false;
  bool _isClosing = false;
  final CodeLineEditingController _controller = CodeLineEditingController.fromText('');
  late final ScrollController _verticalScroller;
  late final ScrollController _horizontalScroller;
  
  static const platform = MethodChannel('window_events');

  void _logToFile(String message) {
    try {
      final logFile = File('C:\\Users\\summo\\OneDrive\\Desktop\\crash_debug.log');
      logFile.writeAsStringSync('${DateTime.now()}: $message\n', mode: FileMode.append, flush: true);
    } catch (e) {
      // Ignore logging errors
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize scroll controllers with faster physics
    _verticalScroller = ScrollController();
    _horizontalScroller = ScrollController();
    _logToFile('FileEditor: Window created, observer added');
    _initialize();
  }
  
  @override
  void dispose() {
    _logToFile('FileEditor: dispose() called');
    _controller.dispose();
    _verticalScroller.dispose();
    _horizontalScroller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    _logToFile('FileEditor: dispose() complete');
  }

  Future<void> _initialize() async {
    try {
      // Initialize Hive for this window
      await Hive.initFlutter();
      
      // Extract file data from arguments
      _fileName = widget.args['fileName'] as String;
      _projectPath = widget.args['projectPath'] as String;
      _content = widget.args['content'] as String;
      _currentContent = _content;
      
      // Initialize editor controller  
      _controller.text = _content;
      _controller.addListener(() {
        final newContent = _controller.text;
        _currentContent = newContent;
        final hasChanges = newContent != _content;
        if (_isModified != hasChanges && mounted) {
          setState(() => _isModified = hasChanges);
        }
      });
      
      // Guard against setState after dispose
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e, stackTrace) {
      print('FileEditor: Initialization failed: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _closeWindow() async {
    if (_isClosing) {
      _logToFile('FileEditor: _closeWindow called while already closing, ignoring');
      return;
    }
    _isClosing = true;

    _logToFile('=== START _closeWindow ===');
    print('\n===== FileEditor: START _closeWindow =====');
    print('FileEditor: Modified: $_isModified');
    print('FileEditor: File: $_fileName');
    
    try {
      // No WebView cleanup needed anymore - just close
      _logToFile('Closing window immediately');
      print('FileEditor: Closing window');
      
      await platform.invokeMethod('confirmClose');
      
    } catch (e, stack) {
      _logToFile('ERROR in _closeWindow: $e');
      _logToFile('Stack: $stack');
      print('===== FileEditor: ERROR in _closeWindow =====');
      print('FileEditor: Error: $e');
      print('FileEditor: Stack: $stack');
    }
  }

  Future<void> _saveFile() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final fileService = FileService();
    final success = await fileService.writeGovernanceFile(
      _projectPath,
      _fileName,
      _currentContent,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      setState(() {
        _isModified = false;
        _content = _currentContent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_fileName saved successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save $_fileName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        ),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.description,
                  size: 20,
                  color: Colors.blue[300],
                ),
                const SizedBox(width: 12),
                Text(_fileName),
                if (_isModified) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Modified',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (_isModified)
                IconButton(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  onPressed: _isSaving ? null : _saveFile,
                  tooltip: 'Save (Ctrl+S)',
                ),
            ],
          ),
          body: Builder(
            builder: (context) {
              _logToFile('FileEditor: Building CodeEditor widget');
              return CodeEditor(
                controller: _controller,
                wordWrap: true,
                scrollController: CodeScrollController(
                  verticalScroller: _verticalScroller,
                  horizontalScroller: _horizontalScroller,
                ),
                style: const CodeEditorStyle(
                  fontSize: 14.0,
                  fontFamily: 'Consolas',
                ),
              );
            },
          ),
        ),
      ),
    );
  }

}
