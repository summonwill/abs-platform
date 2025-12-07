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
library;

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
      final file = File('$projectPath${Platform.pathSeparator}$fileName');
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
      final file = File('$projectPath${Platform.pathSeparator}$fileName');
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
  ///   Checks for standard ABS files plus any other .md files in the root
  Future<List<String>> detectGovernanceFiles(String projectPath) async {
    final files = <String>[];
    
    // Standard governance files (check these first for consistent ordering)
    final standardGovernanceFiles = [
      'AI_RULES_AND_BEST_PRACTICES.md',
      'TODO.md',
      'SESSION_NOTES.md',
      'AI_CONTEXT_INDEX.md',
      'SESSION_BUFFER.md',
    ];

    for (final fileName in standardGovernanceFiles) {
      final file = File('$projectPath${Platform.pathSeparator}$fileName');
      if (await file.exists()) {
        files.add(fileName);
      }
    }
    
    // Also detect any other .md files in the project root that AI may have created
    try {
      final dir = Directory(projectPath);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            // Add any .md files not already in the list
            if (fileName.endsWith('.md') && !files.contains(fileName)) {
              files.add(fileName);
            }
          }
        }
      }
    } catch (e) {
      print('Error scanning for additional files: $e');
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

  /// Get list of all files in project directory (for AI context)
  Future<List<String>> getProjectFileList(String projectPath) async {
    final projectDir = Directory(projectPath);
    if (!await projectDir.exists()) return [];

    final files = <String>[];
    final excludedDirs = {'.git', 'node_modules', '.dart_tool', 'build', '.idea', '.vscode'};
    final excludedExtensions = {'.exe', '.dll', '.so', '.dylib', '.jar', '.zip', '.png', '.jpg', '.jpeg', '.gif'};

    await for (final entity in projectDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path.replaceFirst('$projectPath${Platform.pathSeparator}', '');
        
        // Skip excluded directories
        if (excludedDirs.any((dir) => relativePath.contains('${Platform.pathSeparator}$dir${Platform.pathSeparator}') || relativePath.startsWith('$dir${Platform.pathSeparator}'))) {
          continue;
        }
        
        // Skip excluded file extensions
        if (excludedExtensions.any((ext) => relativePath.toLowerCase().endsWith(ext))) {
          continue;
        }
        
        files.add(relativePath);
      }
    }

    return files..sort();
  }

  /// Read any file in the project (not just governance files)
  Future<String?> readProjectFile(String projectPath, String relativePath) async {
    try {
      final file = File('$projectPath${Platform.pathSeparator}$relativePath');
      if (!await file.exists()) return null;
      
      // Check file size to avoid loading huge files
      final size = await file.length();
      if (size > 1024 * 1024) { // 1MB limit
        return '[File too large: ${(size / 1024).toStringAsFixed(1)} KB]';
      }
      
      return await file.readAsString();
    } catch (e) {
      return '[Error reading file: $e]';
    }
  }

  /// Write or create any project file
  /// 
  /// Parameters:
  ///   - projectPath: Root path of the project
  ///   - relativePath: Relative path to file (e.g., 'src/main.dart', 'lib/models/user.dart')
  ///   - content: Content to write
  /// 
  /// Returns: true if successful, false otherwise
  /// 
  /// Side Effects: Creates parent directories if they don't exist
  Future<bool> writeProjectFile(String projectPath, String relativePath, String content) async {
    try {
      // Normalize path separators for Windows
      final normalizedPath = relativePath.replaceAll('/', Platform.pathSeparator);
      final fullPath = '$projectPath${Platform.pathSeparator}$normalizedPath';
      
      print('DEBUG writeProjectFile:');
      print('  projectPath: $projectPath');
      print('  relativePath: $relativePath');
      print('  fullPath: $fullPath');
      print('  content length: ${content.length}');
      
      final file = File(fullPath);
      
      // Create parent directory if it doesn't exist
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        print('  Creating parent directory: ${parentDir.path}');
        await parentDir.create(recursive: true);
      }
      
      await file.writeAsString(content);
      print('  SUCCESS: File written');
      return true;
    } catch (e) {
      print('ERROR writing file $relativePath: $e');
      return false;
    }
  }

  /// Delete a project file
  /// 
  /// Parameters:
  ///   - projectPath: Root path of the project
  ///   - relativePath: Relative path to file
  /// 
  /// Returns: true if successful, false otherwise
  Future<bool> deleteProjectFile(String projectPath, String relativePath) async {
    try {
      print('DEBUG deleteProjectFile: projectPath=$projectPath, relativePath=$relativePath');
      final file = File('$projectPath${Platform.pathSeparator}$relativePath');
      print('  Full path: ${file.path}');
      if (await file.exists()) {
        await file.delete();
        print('  SUCCESS: File deleted');
        return true;
      }
      print('  File does not exist');
      return false;
    } catch (e) {
      print('Error deleting file $relativePath: $e');
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

  /// Export full project context including file tree (for AI)
  Future<Map<String, dynamic>> exportFullProjectForAI(String projectPath) async {
    final governanceFiles = await exportForAI(projectPath);
    final fileList = await getProjectFileList(projectPath);
    
    return {
      'governanceFiles': governanceFiles,
      'fileTree': fileList,
      'projectPath': projectPath,
    };
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
