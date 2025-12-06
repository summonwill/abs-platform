/// ABS Platform - File Service
/// 
/// Purpose: File system operations for project and governance file management
/// Key Components:
///   - Directory management (app directory, projects directory)
///   - Governance file reading and writing
///   - File picker integration for folder selection
///   - File existence and validation checks
/// 
/// Dependencies:
///   - path_provider: Platform-specific directory access
///   - file_picker: Native file/folder selection dialogs
/// 
/// Last Modified: December 5, 2025

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

/// Service for managing project files and governance documents
/// 
/// Handles all file system interactions for the ABS platform
class FileService {
  /// Get the app's documents directory
  /// 
  /// Returns: Platform-specific documents directory for storing app data
  /// 
  /// Platform behavior:
  ///   - Windows: C:\Users\{user}\Documents
  ///   - macOS: ~/Documents
  ///   - Linux: ~/Documents
  Future<Directory> getAppDirectory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Get the projects directory
  /// 
  /// Returns: Directory at {documents}/ABS_Projects
  /// 
  /// Side Effects: Creates directory if it doesn't exist
  Future<Directory> getProjectsDirectory() async {
    final appDir = await getAppDirectory();
    final projectsDir = Directory('${appDir.path}/ABS_Projects');
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }
    return projectsDir;
  }

  /// Pick a folder for a new project using native file picker
  /// 
  /// Returns: Absolute path to selected folder, or null if cancelled
  /// 
  /// Opens platform-native folder selection dialog
  Future<String?> pickProjectFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Project Folder',
    );
    return result;
  }

  /// Read a governance file from project directory
  /// 
  /// Parameters:
  ///   - projectPath: Absolute path to project folder
  ///   - fileName: Name of governance file (e.g., 'TODO.md')
  /// 
  /// Returns: File contents as string, or null if file doesn't exist or error occurs
  Future<String?> readGovernanceFile(String projectPath, String fileName) async {
    try {
      final file = File('$projectPath/$fileName');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      print('Error reading file $fileName: $e');
      return null;
    }
  }

  /// Write content to a governance file
  /// 
  /// Parameters:
  ///   - projectPath: Absolute path to project folder
  ///   - fileName: Name of governance file to write
  ///   - content: Text content to write to file
  /// 
  /// Returns: true if write succeeded, false if error occurred
  /// 
  /// Side Effects: Creates or overwrites file at {projectPath}/{fileName}
  Future<bool> writeGovernanceFile(
    String projectPath,
    String fileName,
    String content,
  ) async {
    try {
      final file = File('$projectPath/$fileName');
      await file.writeAsString(content);
      return true;
    } catch (e) {
      print('Error writing file $fileName: $e');
      return false;
    }
  }

  /// Check if governance files exist in a project
  /// 
  /// Parameters:
  ///   - projectPath: Absolute path to project folder
  /// 
  /// Returns: List of governance file names that exist in the project
  ///   Checks for: AI_RULES_AND_BEST_PRACTICES.md, TODO.md,
  ///   SESSION_NOTES.md, AI_CONTEXT_INDEX.md, SESSION_BUFFER.md
  Future<List<String>> detectGovernanceFiles(String projectPath) async {
    final files = <String>[];
    final governanceFiles = [
      'AI_RULES_AND_BEST_PRACTICES.md',
      'TODO.md',
      'SESSION_NOTES.md',
      'AI_CONTEXT_INDEX.md',
      'SESSION_BUFFER.md',
    ];

    for (final fileName in governanceFiles) {
      final file = File('$projectPath/$fileName');
      if (await file.exists()) {
        files.add(fileName);
      }
    }

    return files;
  }

  /// Generate initial governance files for a new project
  Future<bool> generateGovernanceFiles(String projectPath, String projectName) async {
    try {
      // Create AI_RULES_AND_BEST_PRACTICES.md
      await writeGovernanceFile(
        projectPath,
        'AI_RULES_AND_BEST_PRACTICES.md',
        _getABSTemplate(),
      );

      // Create TODO.md
      await writeGovernanceFile(
        projectPath,
        'TODO.md',
        _getTodoTemplate(projectName),
      );

      // Create SESSION_NOTES.md
      await writeGovernanceFile(
        projectPath,
        'SESSION_NOTES.md',
        _getSessionNotesTemplate(projectName),
      );

      // Create AI_CONTEXT_INDEX.md
      await writeGovernanceFile(
        projectPath,
        'AI_CONTEXT_INDEX.md',
        _getContextIndexTemplate(projectName),
      );

      return true;
    } catch (e) {
      print('Error generating governance files: $e');
      return false;
    }
  }

  /// Export governance files as a package for AI conversation
  Future<Map<String, String>> exportForAI(String projectPath) async {
    final files = <String, String>{};
    final governanceFiles = [
      'AI_RULES_AND_BEST_PRACTICES.md',
      'TODO.md',
      'SESSION_NOTES.md',
      'AI_CONTEXT_INDEX.md',
    ];

    for (final fileName in governanceFiles) {
      final content = await readGovernanceFile(projectPath, fileName);
      if (content != null) {
        files[fileName] = content;
      }
    }

    return files;
  }

  // Template methods
  String _getABSTemplate() {
    return '''# AI Rules and Best Practices

**Version:** 1.3  
**Status:** Production Standard  
**Scope:** The universal standard for AI-assisted work

This file defines how AI agents should operate within this project.
For full documentation, visit: https://github.com/summonwill/AI-Bootstrap-Framework

## Core Principles

1. **Safety First**: Always classify risk before taking action
2. **Transparency**: Document all decisions and uncertainties
3. **Verification**: Test and validate all changes
4. **Continuity**: Maintain session state and project context
''';
  }

  String _getTodoTemplate(String projectName) {
    return '''# Project TODO - $projectName

## Active Tasks

- [ ] Define project goals
- [ ] Set up initial structure
- [ ] Begin development

## Completed Tasks

- [x] Created project with ABS governance files
''';
  }

  String _getSessionNotesTemplate(String projectName) {
    return '''# Session Notes - $projectName

## [${DateTime.now().toString().split(' ')[0]}] Session 1: Project Initialization

- Created project: $projectName
- Generated initial governance files
- Ready for AI-assisted development
''';
  }

  String _getContextIndexTemplate(String projectName) {
    return '''# AI Context Index - $projectName

## Project Overview

This project uses the AI Bootstrap System for governance and project management.

## Key Files

- `AI_RULES_AND_BEST_PRACTICES.md` - AI governance rules
- `TODO.md` - Task tracking
- `SESSION_NOTES.md` - Session logs
- `AI_CONTEXT_INDEX.md` - This file (project context map)
''';
  }
}
