/// ABS Platform - Data Models
/// 
/// Purpose: Core data models for projects, sessions, and project status
/// Key Components:
///   - Project: Main project entity with governance files and sessions
///   - Session: Work session tracking with conversation history
///   - ProjectStatus: Enum for project lifecycle states
/// 
/// Dependencies:
///   - uuid: Unique identifier generation
/// 
/// Last Modified: December 5, 2025

import 'package:uuid/uuid.dart';

/// Represents an ABS project with governance files and sessions
/// 
/// Contains all project metadata, governance file tracking,
/// session history, and provides helper methods for project state
class Project {
  final String id;
  final String name;
  final String path;
  final String? description;
  final DateTime createdAt;
  final DateTime lastModified;
  final List<String> governanceFiles;
  final List<Session> sessions;
  final ProjectStatus status;

  Project({
    String? id,
    required this.name,
    required this.path,
    this.description,
    DateTime? createdAt,
    DateTime? lastModified,
    List<String>? governanceFiles,
    List<Session>? sessions,
    this.status = ProjectStatus.active,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now(),
        governanceFiles = governanceFiles ?? [],
        sessions = sessions ?? [];

  /// Check if project has required governance files
  /// 
  /// Returns: true if all three core governance files are present:
  ///   - AI_RULES_AND_BEST_PRACTICES.md
  ///   - TODO.md
  ///   - SESSION_NOTES.md
  bool get hasGovernanceFiles {
    return governanceFiles.contains('AI_RULES_AND_BEST_PRACTICES.md') &&
        governanceFiles.contains('TODO.md') &&
        governanceFiles.contains('SESSION_NOTES.md');
  }

  /// Get the most recent session
  /// 
  /// Returns: The session with the latest startedAt timestamp,
  ///   or null if no sessions exist
  Session? get lastSession {
    if (sessions.isEmpty) return null;
    return sessions.reduce((a, b) => a.startedAt.isAfter(b.startedAt) ? a : b);
  }

  /// Copy with method for immutability
  Project copyWith({
    String? name,
    String? path,
    String? description,
    DateTime? lastModified,
    List<String>? governanceFiles,
    List<Session>? sessions,
    ProjectStatus? status,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      path: path ?? this.path,
      description: description ?? this.description,
      createdAt: createdAt,
      lastModified: lastModified ?? this.lastModified,
      governanceFiles: governanceFiles ?? this.governanceFiles,
      sessions: sessions ?? this.sessions,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'governanceFiles': governanceFiles,
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'status': status.toString(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Project',
      path: json['path'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
      governanceFiles: List<String>.from(json['governanceFiles'] ?? []),
      sessions: (json['sessions'] as List?)
              ?.map((s) => Session.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      status: ProjectStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => ProjectStatus.active,
      ),
    );
  }
}

enum ProjectStatus {
  active,
  archived,
  template,
}

/// Represents a work session within a project
class Session {
  final String id;
  final String projectId;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final List<String> filesModified;
  final SessionStatus status;
  final List<Map<String, dynamic>> conversationHistory;

  Session({
    String? id,
    required this.projectId,
    required this.title,
    DateTime? startedAt,
    this.endedAt,
    this.notes,
    List<String>? filesModified,
    this.status = SessionStatus.inProgress,
    List<Map<String, dynamic>>? conversationHistory,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now(),
        filesModified = filesModified ?? [],
        conversationHistory = conversationHistory ?? [];

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  bool get isActive => status == SessionStatus.inProgress;

  Session copyWith({
    String? title,
    DateTime? endedAt,
    String? notes,
    List<String>? filesModified,
    SessionStatus? status,
    List<Map<String, dynamic>>? conversationHistory,
  }) {
    return Session(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      notes: notes ?? this.notes,
      filesModified: filesModified ?? this.filesModified,
      status: status ?? this.status,
      conversationHistory: conversationHistory ?? this.conversationHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'notes': notes,
      'filesModified': filesModified,
      'status': status.toString(),
      'conversationHistory': conversationHistory,
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String?,
      projectId: json['projectId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Session',
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now(),
      endedAt: json['endedAt'] != null 
          ? DateTime.parse(json['endedAt'] as String) 
          : null,
      notes: json['notes'] as String?,
      filesModified: List<String>.from(json['filesModified'] ?? []),
      status: SessionStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => SessionStatus.completed,
      ),
      conversationHistory: json['conversationHistory'] != null
          ? List<Map<String, dynamic>>.from(json['conversationHistory'])
          : [],
    );
  }
}

enum SessionStatus {
  inProgress,
  completed,
  cancelled,
}
