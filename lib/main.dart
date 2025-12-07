/// AI Bootstrap System (ABS) Platform - Main Entry Point
/// 
/// Purpose: Application initialization and routing for main window and sub-windows
/// Key Components:
///   - Main window: ProjectsScreen
///   - Sub-windows: AIChatWindow, FileEditorWindow (separate OS windows)
/// Dependencies:
///   - Hive: Local storage initialization
///   - window_manager: Desktop window configuration
///   - desktop_multi_window: Multi-window support
/// 
/// Last Modified: December 5, 2025
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'screens/projects_screen.dart';
import 'windows/ai_chat_window.dart';
import 'windows/file_editor_window.dart';
import 'services/debug_logger.dart';

/// Application entry point
/// 
/// Handles:
///   - Sub-window routing (when args[0] == 'multi_window')
///   - Main window initialization
///   - Hive storage setup
///   - Desktop window configuration
/// 
/// Parameters:
///   - args: Command line arguments for window routing
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize debug logger
  await DebugLogger.initialize();
  await DebugLogger.log('App starting with args: $args');

  // Handle sub-window creation
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    final controller = WindowController.fromWindowId(windowId);
    
    // Parse arguments from JSON
    final arguments = args.length > 2
        ? jsonDecode(args[2]) as Map<String, dynamic>
        : <String, dynamic>{};

    // Route to appropriate window type
    final windowType = arguments['windowType'] as String?;
    if (windowType == 'file_editor') {
      runApp(FileEditorWindow(controller: controller, args: arguments));
    } else {
      // Default to AI chat window for backward compatibility
      runApp(AIChatWindow(controller: controller, args: arguments));
    }
    return;
  }

  // Initialize Hive
  await Hive.initFlutter();

  // Configure window for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'ABS Studio',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    const ProviderScope(
      child: ABSApp(),
    ),
  );
}

class ABSApp extends StatelessWidget {
  const ABSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Bootstrap System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const ProjectsScreen(),
    );
  }
}
