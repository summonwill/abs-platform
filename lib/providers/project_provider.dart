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
import 'package:flutter/foundation.dart';
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
    // Clean up orphaned sessions (inProgress with no heartbeat)
    final cleanedProjects = await _cleanupOrphanedSessions(projects);
    state = cleanedProjects;
  }

  /// Clean up sessions that are stuck in 'inProgress' state
  /// 
  /// This handles sessions that weren't properly closed due to:
  /// - App crash before heartbeat detection
  /// - Sessions from before heartbeat mechanism was implemented
  /// - Any other corruption that left sessions without endedAt
  Future<List<Project>> _cleanupOrphanedSessions(List<Project> projects) async {
    bool anyChanges = false;
    final cleanedProjects = <Project>[];
    
    for (final project in projects) {
      final cleanedSessions = <Session>[];
      
      for (final session in project.sessions) {
        if (session.status == SessionStatus.inProgress) {
          // Session is marked active but app just started - it's orphaned
          // Preserve accumulated duration but don't add unknown time from crash
          print('DEBUG: Found orphaned session "${session.title}" - marking as completed (preserving ${session.accumulatedDuration.inMinutes}m accumulated)');
          cleanedSessions.add(session.copyWith(
            status: SessionStatus.completed,
            endedAt: session.startedAt, // Set endedAt to startedAt so current period = 0
            // accumulatedDuration is preserved automatically
          ));
          anyChanges = true;
        } else if (session.status == SessionStatus.completed && session.endedAt == null) {
          // Completed but missing endedAt - fix the data
          print('DEBUG: Found corrupted session "${session.title}" (completed but no endedAt) - fixing');
          cleanedSessions.add(session.copyWith(
            endedAt: session.startedAt, // Set to startedAt so current period = 0
          ));
          anyChanges = true;
        } else {
          cleanedSessions.add(session);
        }
      }
      
      cleanedProjects.add(project.copyWith(sessions: cleanedSessions));
    }
    
    // Save if we made any changes
    if (anyChanges) {
      print('DEBUG: Saving cleaned up sessions');
      // We need to save manually since state isn't set yet
      if (_box != null) {
        await _box!.clear();
        for (var project in cleanedProjects) {
          await _box!.put(project.id, json.encode(project.toJson()));
        }
      }
    }
    
    return cleanedProjects;
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
  
  /// Sync chat history from .abs_chat_history.json file (written by separate windows)
  /// This syncs the conversation history and session state from the file
  /// The file contains the authoritative session state (including completed status if window closed)
  Future<Project?> syncChatHistoryFromFile(String projectId) async {
    final project = getProject(projectId);
    if (project == null) return null;
    
    try {
      final file = File('${project.path}${Platform.pathSeparator}.abs_chat_history.json');
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
        final fileProject = Project.fromJson(jsonMap);
        
        print('DEBUG syncChatHistory: File project has ${fileProject.sessions.length} sessions');
        for (final s in fileProject.sessions) {
          print('DEBUG syncChatHistory: File session "${s.title}" status=${s.status}, isActive=${s.isActive}');
        }
        
        // Merge sessions - always use file session data as it's more up-to-date
        // The file is the authoritative source since the chat window writes to it
        final mergedSessions = <Session>[];
        for (final session in project.sessions) {
          final fileSession = fileProject.sessions.firstWhere(
            (s) => s.id == session.id,
            orElse: () => session,
          );
          
          // Always use file session if it has same or more messages
          // File session has the correct status (completed if window closed, inProgress if still open)
          if (fileSession.conversationHistory.length >= session.conversationHistory.length) {
            print('DEBUG syncChatHistory: Using file session for "${session.title}" (status=${fileSession.status})');
            mergedSessions.add(fileSession);
          } else {
            print('DEBUG syncChatHistory: Using local session for "${session.title}" (more messages locally)');
            mergedSessions.add(session);
          }
        }
        
        // Add any new sessions from file
        for (final fileSession in fileProject.sessions) {
          if (!mergedSessions.any((s) => s.id == fileSession.id)) {
            mergedSessions.add(fileSession);
          }
        }
        
        final updatedProject = project.copyWith(
          sessions: mergedSessions,
          lastModified: DateTime.now(),
        );
        
        await updateProject(updatedProject);
        
        // Delete the file after syncing
        await file.delete();
        print('DEBUG: Synced chat history from file and deleted it');
        
        return updatedProject;
      }
    } catch (e) {
      print('DEBUG: Error syncing chat history: $e');
    }
    return null;
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
  
  /// End a specific session
  Future<void> endSession(String projectId, String sessionId) async {
    final project = getProject(projectId);
    if (project == null) return;
    
    final updatedSessions = project.sessions.map((session) {
      if (session.id == sessionId && session.isActive) {
        return session.copyWith(
          endedAt: DateTime.now(),
          status: SessionStatus.completed,
        );
      }
      return session;
    }).toList();
    
    final updatedProject = project.copyWith(
      sessions: updatedSessions,
      lastModified: DateTime.now(),
    );
    
    await updateProject(updatedProject);
  }
  
  /// Delete a session from a project
  Future<void> deleteSession(String projectId, String sessionId) async {
    final project = getProject(projectId);
    if (project == null) return;
    
    final updatedSessions = project.sessions.where((s) => s.id != sessionId).toList();
    
    final updatedProject = project.copyWith(
      sessions: updatedSessions,
      lastModified: DateTime.now(),
    );
    
    await updateProject(updatedProject);
  }
  
  /// Activate a specific session (deactivates others)
  Future<void> activateSession(String projectId, String sessionId) async {
    final project = getProject(projectId);
    if (project == null) return;
    
    final updatedSessions = project.sessions.map((session) {
      if (session.id == sessionId) {
        // Activate this session (reopen it)
        // Store the total duration so far, then reset the timer
        final totalSoFar = session.duration; // This is accumulated + (endedAt - startedAt)
        debugPrint('DEBUG activateSession: Reactivating session ${session.id}');
        debugPrint('DEBUG activateSession: Previous accumulated: ${session.accumulatedDuration.inSeconds}s');
        debugPrint('DEBUG activateSession: Total so far: ${totalSoFar.inSeconds}s');
        return session.copyWith(
          status: SessionStatus.inProgress,
          startedAt: DateTime.now(), // Reset timer to now
          clearEndedAt: true, // Explicitly clear end time
          accumulatedDuration: totalSoFar, // Carry forward the total
        );
      } else if (session.isActive) {
        // Deactivate other active sessions
        return session.copyWith(
          endedAt: DateTime.now(),
          status: SessionStatus.completed,
        );
      }
      return session;
    }).toList();
    
    final updatedProject = project.copyWith(
      sessions: updatedSessions,
      lastModified: DateTime.now(),
    );
    
    await updateProject(updatedProject);
  }
  
  /// Rename a session
  Future<void> renameSession(String projectId, String sessionId, String newTitle) async {
    final project = getProject(projectId);
    if (project == null) return;
    
    final updatedSessions = project.sessions.map((session) {
      if (session.id == sessionId) {
        return session.copyWith(title: newTitle);
      }
      return session;
    }).toList();
    
    final updatedProject = project.copyWith(
      sessions: updatedSessions,
      lastModified: DateTime.now(),
    );
    
    await updateProject(updatedProject);
  }
  
  /// Reorder sessions (move session from oldIndex to newIndex)
  Future<void> reorderSessions(String projectId, int oldIndex, int newIndex) async {
    final project = getProject(projectId);
    if (project == null) return;
    
    final sessions = List<Session>.from(project.sessions);
    
    // Adjust for the "New Session" button at index 0 in the UI
    // The actual session indices are offset by 1 in the UI
    if (oldIndex < 0 || oldIndex >= sessions.length) return;
    if (newIndex < 0 || newIndex >= sessions.length) return;
    
    final session = sessions.removeAt(oldIndex);
    sessions.insert(newIndex, session);
    
    final updatedProject = project.copyWith(
      sessions: sessions,
      lastModified: DateTime.now(),
    );
    
    await updateProject(updatedProject);
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
