/// ABS Platform - File Editor Window (Separate OS Window)
/// 
/// Purpose: Entry point for separate file editor windows spawned via desktop_multi_window
/// Key Components:
///   - Window initialization and Hive setup
///   - Custom dark title bar
///   - MonacoEditor integration in isolated window process
///   - File data reconstruction from JSON arguments
/// 
/// Dependencies:
///   - desktop_multi_window: Multi-window infrastructure
///   - hive_flutter: Storage access in separate window
///   - monaco_editor: High-performance editor widget
/// 
/// Last Modified: December 5, 2025

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/monaco_editor.dart';
import '../services/file_service.dart';
import '../services/debug_logger.dart';

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

class _FileEditorWindowState extends State<FileEditorWindow> {
  bool _isInitialized = false;
  late String _fileName;
  late String _projectPath;
  late String _content;
  late String _currentContent;
  bool _isModified = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await DebugLogger.log('FileEditor: Starting initialization');
      
      // Initialize Hive for this window
      await Hive.initFlutter();
      await DebugLogger.log('FileEditor: Hive initialized');
      
      // Extract file data from arguments
      _fileName = widget.args['fileName'] as String;
      _projectPath = widget.args['projectPath'] as String;
      _content = widget.args['content'] as String;
      _currentContent = _content;
      
      await DebugLogger.log('FileEditor: Opening file: $_fileName (${_content.length} chars)');
      
      setState(() => _isInitialized = true);
      await DebugLogger.log('FileEditor: Initialization complete');
    } catch (e, stackTrace) {
      await DebugLogger.error('FileEditor: Initialization failed', e, stackTrace);
      rethrow;
    }
  }

  void _onContentChanged(String newContent) {
    _currentContent = newContent;
    final hasChanges = newContent != _content;
    if (_isModified != hasChanges) {
      setState(() => _isModified = hasChanges);
    }
  }

  Future<void> _saveFile() async {
    setState(() => _isSaving = true);

    final fileService = FileService();
    final success = await fileService.writeGovernanceFile(
      _projectPath,
      _fileName,
      _currentContent,
    );

    setState(() => _isSaving = false);

    if (mounted) {
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
          body: Column(
            children: [
              // Custom dark title bar
              Container(
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF2D2D2D),
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF3D3D3D),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    // File Icon
                    Icon(
                      Icons.description,
                      size: 20,
                      color: Colors.blue[300],
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: Text(
                        _fileName,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Modified indicator
                    if (_isModified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
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
                    // Save button
                    if (_isModified)
                      IconButton(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save, size: 20),
                        onPressed: _isSaving ? null : _saveFile,
                        tooltip: 'Save',
                        color: Colors.green[300],
                      ),
                    // Close button
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        if (_isModified) {
                          _showUnsavedChangesDialog();
                        } else {
                          widget.controller.close();
                        }
                      },
                      tooltip: 'Close',
                      hoverColor: Colors.red.withOpacity(0.2),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              // Editor content
              Expanded(
                child: MonacoEditor(
                  initialContent: _content,
                  language: _fileName.endsWith('.md') ? 'markdown' : 'plaintext',
                  onChanged: _onContentChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.controller.close();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
