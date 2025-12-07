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
  /// Returns: List of relative file paths that exist in the project
  ///   Includes standard ABS files plus all supported files in subfolders
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
    
    // Supported file extensions for AI-created files
    final supportedExtensions = [
      '.md', '.txt', '.py', '.json', '.yaml', '.yml', 
      '.csv', '.bat', '.sh', '.ps1', '.vbs', '.js', '.html', '.css',
    ];
    
    // Folders to exclude from scanning
    final excludedFolders = {
      '.git', 'node_modules', '__pycache__', '.venv', 'venv',
      '.idea', '.vscode', 'build', 'dist', '.dart_tool',
    };
    
    // Recursively scan all subfolders for supported files
    try {
      final dir = Directory(projectPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            // Get relative path from project root
            final relativePath = entity.path
                .replaceFirst('$projectPath${Platform.pathSeparator}', '')
                .replaceAll(Platform.pathSeparator, '/'); // Normalize to forward slashes for display
            
            // Skip excluded folders
            if (excludedFolders.any((folder) => relativePath.startsWith('$folder/') || relativePath.contains('/$folder/'))) {
              continue;
            }
            
            // Check if file has supported extension
            final ext = relativePath.toLowerCase();
            if (supportedExtensions.any((e) => ext.endsWith(e)) && !files.contains(relativePath)) {
              files.add(relativePath);
            }
          }
        }
      }
    } catch (e) {
      print('Error scanning for project files: $e');
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
      // Normalize path separators for Windows
      final normalizedPath = relativePath.replaceAll('/', Platform.pathSeparator);
      final fullPath = '$projectPath${Platform.pathSeparator}$normalizedPath';
      
      print('DEBUG readProjectFile: $fullPath');
      
      final file = File(fullPath);
      if (!await file.exists()) {
        print('  File does not exist');
        return null;
      }
      
      // Check file size to avoid loading huge files
      final size = await file.length();
      if (size > 1024 * 1024) { // 1MB limit
        print('  File too large: ${(size / 1024).toStringAsFixed(1)} KB');
        return '[File too large: ${(size / 1024).toStringAsFixed(1)} KB]';
      }
      
      final content = await file.readAsString();
      print('  SUCCESS: Read ${content.length} chars');
      return content;
    } catch (e) {
      print('  ERROR: $e');
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
  /// If relativePath ends with /, creates a directory instead of a file
  Future<bool> writeProjectFile(String projectPath, String relativePath, String content) async {
    try {
      // Check if this is a folder creation request (path ends with /)
      if (relativePath.endsWith('/')) {
        // This is a folder creation request
        final folderPath = relativePath.substring(0, relativePath.length - 1);
        final normalizedPath = folderPath.replaceAll('/', Platform.pathSeparator);
        final fullPath = '$projectPath${Platform.pathSeparator}$normalizedPath';
        
        print('DEBUG writeProjectFile (FOLDER):');
        print('  projectPath: $projectPath');
        print('  relativePath: $relativePath');
        print('  fullPath: $fullPath');
        
        final dir = Directory(fullPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
          print('  SUCCESS: Folder created');
        } else {
          print('  Folder already exists');
        }
        return true;
      }
      
      // Regular file creation
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
      // Convert forward slashes to platform separator
      final cleanPath = relativePath.replaceAll('/', Platform.pathSeparator);
      
      print('DEBUG deleteProjectFile: projectPath=$projectPath, relativePath=$cleanPath');
      final file = File('$projectPath${Platform.pathSeparator}$cleanPath');
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
  
  /// Delete a project folder and all its contents
  /// 
  /// Parameters:
  ///   - projectPath: Root path of the project
  ///   - relativePath: Relative path to folder (with or without trailing slash)
  /// 
  /// Returns: true if successful, false otherwise
  Future<bool> deleteProjectFolder(String projectPath, String relativePath) async {
    // Remove trailing slash if present for consistency
    var cleanPath = relativePath.endsWith('/') 
        ? relativePath.substring(0, relativePath.length - 1) 
        : relativePath;
    
    // Also remove backslash if present
    if (cleanPath.endsWith('\\')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    }
    
    // Convert forward slashes to platform separator
    cleanPath = cleanPath.replaceAll('/', Platform.pathSeparator);
    
    // Build full path, avoiding double separators
    final fullPath = projectPath.endsWith(Platform.pathSeparator)
        ? '$projectPath$cleanPath'
        : '$projectPath${Platform.pathSeparator}$cleanPath';
    
    print('DEBUG deleteProjectFolder:');
    print('  fullPath: "$fullPath"');
    
    final dir = Directory(fullPath);
    
    if (!await dir.exists()) {
      print('  Folder does not exist');
      return false;
    }
    
    // On Windows, try using cmd /c rmdir which can handle some locked files better
    if (Platform.isWindows) {
      try {
        print('  Trying Windows rmdir command...');
        final result = await Process.run(
          'cmd',
          ['/c', 'rmdir', '/s', '/q', fullPath],
          runInShell: true,
        );
        
        print('  rmdir exit code: ${result.exitCode}');
        if (result.stderr.toString().isNotEmpty) {
          print('  rmdir stderr: ${result.stderr}');
        }
        
        // Check if directory was deleted
        if (!await dir.exists()) {
          print('  SUCCESS: Folder deleted via rmdir');
          return true;
        }
      } catch (e) {
        print('  rmdir failed: $e');
      }
    }
    
    // Fallback: Try Dart's delete with retries
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('  Dart delete attempt $attempt...');
        
        // First, try to delete all files inside individually
        await _deleteContentsRecursively(dir);
        
        // Now try to delete the empty directory
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        
        print('  SUCCESS: Folder deleted');
        return true;
      } catch (e) {
        print('  Attempt $attempt failed: $e');
        if (attempt < 3) {
          final delay = attempt * 300;
          print('  Waiting ${delay}ms before retry...');
          await Future.delayed(Duration(milliseconds: delay));
        }
      }
    }
    
    print('  FAILED: Could not delete folder');
    return false;
  }
  
  /// Helper to delete directory contents file by file
  Future<void> _deleteContentsRecursively(Directory dir) async {
    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (e) {
            print('    Could not delete file: ${entity.path} - $e');
          }
        } else if (entity is Directory) {
          await _deleteContentsRecursively(entity);
          try {
            await entity.delete();
          } catch (e) {
            print('    Could not delete subdir: ${entity.path} - $e');
          }
        }
      }
    } catch (e) {
      print('    Error listing directory: $e');
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

  /// Export full project context including ALL file contents (for AI)
  /// 
  /// Loads the complete project into memory so AI has full access to:
  /// - All governance files
  /// - All project files and their contents
  /// - Complete file tree structure
  /// 
  /// This is called on EVERY message, so new files/folders created during
  /// the session are automatically included in subsequent messages.
  /// 
  /// Files larger than 100KB are skipped to prevent context overflow.
  /// Binary files are skipped.
  Future<Map<String, dynamic>> exportFullProjectForAI(String projectPath) async {
    print('DEBUG exportFullProjectForAI: Scanning project for all files...');
    
    final governanceFiles = await exportForAI(projectPath);
    final fileList = await getProjectFileList(projectPath);
    
    print('DEBUG exportFullProjectForAI: Found ${fileList.length} total files in project');
    
    // Load ALL file contents (not just governance files)
    final allFileContents = <String, String>{};
    
    // Text file extensions we can read
    final textExtensions = [
      '.md', '.txt', '.json', '.yaml', '.yml', '.xml', '.html', '.css', '.js', '.ts',
      '.py', '.dart', '.java', '.kt', '.swift', '.c', '.cpp', '.h', '.hpp', '.cs',
      '.rb', '.php', '.go', '.rs', '.sh', '.bat', '.ps1', '.sql', '.csv', '.ini',
      '.cfg', '.conf', '.toml', '.env', '.gitignore', '.dockerfile', '.vue', '.jsx', '.tsx',
    ];
    
    int totalSize = 0;
    const maxTotalSize = 500 * 1024; // 500KB total limit for all files
    const maxFileSize = 100 * 1024;  // 100KB per file limit
    
    for (final filePath in fileList) {
      // Skip governance files (already in governanceFiles map)
      if (filePath == 'AI_RULES_AND_BEST_PRACTICES.md' ||
          filePath == 'TODO.md' ||
          filePath == 'SESSION_NOTES.md' ||
          filePath == 'AI_CONTEXT_INDEX.md') {
        continue;
      }
      
      // Check if it's a text file we can read
      final extension = filePath.contains('.') 
          ? '.${filePath.split('.').last.toLowerCase()}'
          : '';
      
      if (!textExtensions.contains(extension) && extension.isNotEmpty) {
        print('DEBUG exportFullProjectForAI: Skipping binary file: $filePath');
        continue; // Skip binary files
      }
      
      // Read the file
      final content = await readProjectFile(projectPath, filePath);
      if (content != null && 
          !content.startsWith('[Error') && 
          !content.startsWith('[File too large')) {
        
        // Check size limits
        if (content.length > maxFileSize) {
          allFileContents[filePath] = '[File truncated - ${(content.length / 1024).toStringAsFixed(1)}KB] ${content.substring(0, 1000)}...';
          totalSize += 1000;
          print('DEBUG exportFullProjectForAI: Loaded (truncated): $filePath');
        } else if (totalSize + content.length <= maxTotalSize) {
          allFileContents[filePath] = content;
          totalSize += content.length;
          print('DEBUG exportFullProjectForAI: Loaded: $filePath (${content.length} chars)');
        } else {
          // Stop loading more files if we hit total limit
          print('DEBUG exportFullProjectForAI: Total size limit reached, skipping remaining files');
          break;
        }
      }
    }
    
    print('DEBUG exportFullProjectForAI: Loaded ${allFileContents.length} project files (${(totalSize / 1024).toStringAsFixed(1)}KB)');
    
    return {
      'governanceFiles': governanceFiles,
      'allFileContents': allFileContents,
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
