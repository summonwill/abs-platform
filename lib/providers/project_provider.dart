/// ABS Platform - Project State Management
/// 
/// Purpose: Riverpod state management for projects, sessions, and file operations
/// Key Components:
///   - ProjectsNotifier: StateNotifier for project CRUD operations
///   - Session management: Create, update, end sessions
///   - Governance file synchronization with file system
///   - Hive storage persistence
/// 
/// Dependencies:
///   - flutter_riverpod: State management framework
///   - hive: Local storage
///   - file_service: File system operations
/// 
/// Last Modified: December 5, 2025
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/project.dart';
import '../services/file_service.dart';

/// Provider for FileService singleton
final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

final projectsProvider = StateNotifierProvider<ProjectsNotifier, List<Project>>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  return ProjectsNotifier(fileService);
});

/// Currently selected project (null if none selected)
final selectedProjectProvider = StateProvider<Project?>((ref) => null);

/// State notifier for managing projects list and operations
/// 
/// Handles:
///   - Project CRUD operations
///   - Session lifecycle management
///   - Governance file synchronization
///   - Persistence to Hive storage
class ProjectsNotifier extends StateNotifier<List<Project>> {
  final FileService _fileService;
  Box<String>? _box;

  ProjectsNotifier(this._fileService) : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<String>('projects');
    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (_box == null) return;

    final projects = <Project>[];
    for (var entry in _box!.toMap().entries) {
      try {
        // Parse JSON string to Map
        final jsonStr = entry.value;
        if (jsonStr.isNotEmpty) {
          // Try to parse as JSON
          final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(
            jsonStr.startsWith('{') 
              ? (await _parseJson(jsonStr)) ?? {}
              : {},
          );
          if (jsonMap.isNotEmpty) {
            projects.add(Project.fromJson(jsonMap));
          }
        }
      } catch (e) {
        print('Error loading project: $e');
      }
    }
    state = projects;
  }

  Future<Map<String, dynamic>?> _parseJson(String jsonStr) async {
    try {
      return Map<String, dynamic>.from(
        json.decode(jsonStr) as Map,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveProjects() async {
    if (_box == null) return;

    await _box!.clear();
    for (var project in state) {
      await _box!.put(project.id, json.encode(project.toJson()));
    }
  }

  Future<Project?> createProject({
    required String name,
    required String path,
    String? description,
    bool generateGovernanceFiles = true,
  }) async {
    try {
      // Generate governance files if requested
      if (generateGovernanceFiles) {
        await _fileService.generateGovernanceFiles(path, name);
      }

      // Detect existing governance files
      final governanceFiles = await _fileService.detectGovernanceFiles(path);

      // Create project
      final project = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        path: path,
        description: description,
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        governanceFiles: governanceFiles,
        sessions: [],
        status: ProjectStatus.active,
      );

      state = [...state, project];
      await _saveProjects();

      return project;
    } catch (e) {
      print('Error creating project: $e');
      return null;
    }
  }

  Future<Project?> openProject() async {
    try {
      final path = await _fileService.pickProjectFolder();
      if (path == null) return null;

      // Check if project already exists
      final existingProject = state.firstWhere(
        (p) => p.path == path,
        orElse: () => Project(
          id: '',
          name: '',
          path: '',
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
          governanceFiles: [],
          sessions: [],
          status: ProjectStatus.active,
        ),
      );

      if (existingProject.id.isNotEmpty) {
        return existingProject;
      }

      // Detect governance files
      final governanceFiles = await _fileService.detectGovernanceFiles(path);

      // Create new project
      final projectName = path.split(Platform.pathSeparator).last;
      final project = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: projectName,
        path: path,
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        governanceFiles: governanceFiles,
        sessions: [],
        status: ProjectStatus.active,
      );

      state = [...state, project];
      await _saveProjects();

      return project;
    } catch (e) {
      print('Error opening project: $e');
      return null;
    }
  }

  Future<void> updateProject(Project project) async {
    state = [
      for (final p in state)
        if (p.id == project.id) project else p,
    ];
    await _saveProjects();
  }

  Future<void> deleteProject(String projectId) async {
    state = state.where((p) => p.id != projectId).toList();
    await _saveProjects();
  }

  /// Refresh the governance files list for a project by re-scanning the directory
  /// 
  /// Call this after AI creates, updates, or deletes files to update the UI
  Future<Project?> refreshProjectFiles(String projectId) async {
    final project = getProject(projectId);
    if (project == null) return null;

    try {
      // Re-detect governance files from disk
      final governanceFiles = await _fileService.detectGovernanceFiles(project.path);
      
      // Update project with new file list
      final updatedProject = project.copyWith(
        governanceFiles: governanceFiles,
        lastModified: DateTime.now(),
      );
      
      // Update state
      state = [
        for (final p in state)
          if (p.id == projectId) updatedProject else p,
      ];
      await _saveProjects();
      
      print('DEBUG refreshProjectFiles: Found ${governanceFiles.length} files');
      return updatedProject;
    } catch (e) {
      print('Error refreshing project files: $e');
      return null;
    }
  }

  Project? getProject(String projectId) {
    try {
      return state.firstWhere((p) => p.id == projectId);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String>> exportForAI(String projectId) async {
    final project = getProject(projectId);
    if (project == null) return {};

    return await _fileService.exportForAI(project.path);
  }

  Future<Map<String, dynamic>> exportFullProjectForAI(String projectId) async {
    final project = getProject(projectId);
    if (project == null) return {};

    return await _fileService.exportFullProjectForAI(project.path);
  }

  Future<void> createSession(String projectId, String title) async {
    final project = getProject(projectId);
    if (project == null) return;

    // End any active sessions
    final updatedSessions = project.sessions.map((session) {
      if (session.isActive) {
        return session.copyWith(
          endedAt: DateTime.now(),
          status: SessionStatus.completed,
        );
      }
      return session;
    }).toList();

    // Create new session
    final newSession = Session(
      projectId: projectId,
      title: title,
      startedAt: DateTime.now(),
      status: SessionStatus.inProgress,
    );

    // Update project with new session
    final updatedProject = project.copyWith(
      sessions: [...updatedSessions, newSession],
      lastModified: DateTime.now(),
    );

    await updateProject(updatedProject);

    // Update SESSION_NOTES.md
    await _updateSessionNotes(updatedProject, newSession);
  }

  Future<void> _updateSessionNotes(Project project, Session session) async {
    final existingNotes = await _fileService.readGovernanceFile(
      project.path,
      'SESSION_NOTES.md',
    );

    final date = DateTime.now().toString().split(' ')[0];
    final sessionNumber = project.sessions.length;
    final newEntry = '''

## Session $sessionNumber: $date - ${session.title}

### Objectives
- ${session.title}

### Work Completed
- Session started

### Next Steps
- Define tasks
- Begin work

---
''';

    final updatedNotes = existingNotes != null
        ? '$existingNotes\n$newEntry'
        : '# Session Notes - ${project.name}\n$newEntry';

    await _fileService.writeGovernanceFile(
      project.path,
      'SESSION_NOTES.md',
      updatedNotes,
    );
  }
}
