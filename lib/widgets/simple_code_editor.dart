/// ABS Platform - Code Editor Widget
/// 
/// Purpose: High-performance code editor for large files without WebView
/// Key Components:
///   - CodeField widget optimized for code editing
///   - Syntax highlighting via flutter_highlight
///   - Line numbers and monospace font
/// 
/// Dependencies:
///   - code_text_field: High-performance code editor
///   - flutter_highlight: Syntax highlighting
/// 
/// Performance: Handles 10,000+ line files efficiently
/// 
/// Last Modified: December 5, 2025
library;

import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/dart.dart';

/// Code editor widget with syntax highlighting and line numbers
/// 
/// Uses CodeField for efficient large file handling
class SimpleCodeEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;
  final String language;

  const SimpleCodeEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
    this.language = 'markdown',
  });

  @override
  State<SimpleCodeEditor> createState() => _SimpleCodeEditorState();
}

class _SimpleCodeEditorState extends State<SimpleCodeEditor> {
  CodeController? _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final mode = widget.language == 'markdown' ? markdown : dart;
    
    _controller = CodeController(
      text: widget.initialContent,
      language: mode,
    );

    _controller!.addListener(() {
      widget.onChanged(_controller!.text);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: CodeTheme(
        data: const CodeThemeData(
          styles: vs2015Theme,
        ),
        child: CodeField(
          controller: _controller!,
          textStyle: const TextStyle(
            fontFamily: 'Consolas',
            fontSize: 13,
          ),
          lineNumberStyle: const LineNumberStyle(
            width: 56,
            textAlign: TextAlign.right,
            margin: 8,
            textStyle: TextStyle(
              fontSize: 12,
              color: Color(0xFF858585),
            ),
          ),
        ),
      ),
    );
  }
}
