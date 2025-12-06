/// ABS Platform - AI Chat Window (Separate OS Window)
/// 
/// Purpose: Entry point for separate AI chat windows spawned via desktop_multi_window
/// Key Components:
///   - Window initialization and Hive setup
///   - Custom dark title bar (matches app theme)
///   - AIChatScreen integration in isolated window process
///   - Project data reconstruction from JSON arguments
/// 
/// Dependencies:
///   - desktop_multi_window: Multi-window infrastructure
///   - hive_flutter: Storage access in separate window
///   - ai_chat_screen: Chat UI component
/// 
/// Last Modified: December 5, 2025

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../screens/ai_chat_screen.dart';
import '../models/project.dart';

/// Separate window for AI chat
/// 
/// StatefulWidget to handle async Hive initialization before rendering
class AIChatWindow extends StatefulWidget {
  final WindowController controller;
  final Map<String, dynamic> args;

  const AIChatWindow({
    super.key,
    required this.controller,
    required this.args,
  });

  @override
  State<AIChatWindow> createState() => _AIChatWindowState();
}

class _AIChatWindowState extends State<AIChatWindow> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize Hive for this window to access API keys
    await Hive.initFlutter();
    setState(() => _isInitialized = true);
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

    // Reconstruct project from args
    final project = Project.fromJson(Map<String, dynamic>.from(widget.args));

    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.dark,
        home: Material(
          color: const Color(0xFF1E1E1E),
          child: Column(
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
                    // AI Icon
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 24,
                          color: Colors.blue[300],
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Icon(
                            Icons.settings,
                            size: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: Text(
                        'AI Assistant - ${project.name}',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Close button
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        widget.controller.close();
                      },
                      tooltip: 'Close',
                      hoverColor: Colors.red.withOpacity(0.2),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              // Chat content
              Expanded(
                child: AIChatScreen(project: project),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
