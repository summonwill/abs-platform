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
library;

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

/// Represents a topic discussed within a session
/// 
/// Topics can be AI-detected or user-defined via #topic: tag
class SessionTopic {
  final String name;           // e.g., "heartbeat-timing"
  final String? summary;       // What was discussed about this topic
  final bool isUserDefined;    // User tagged via #topic: vs AI detected
  final DateTime createdAt;    // When this topic was added

  SessionTopic({
    required this.name,
    this.summary,
    this.isUserDefined = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'summary': summary,
    'isUserDefined': isUserDefined,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SessionTopic.fromJson(Map<String, dynamic> json) => SessionTopic(
    name: json['name'] as String? ?? '',
    summary: json['summary'] as String?,
    isUserDefined: json['isUserDefined'] as bool? ?? false,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );

  SessionTopic copyWith({
    String? name,
    String? summary,
    bool? isUserDefined,
  }) => SessionTopic(
    name: name ?? this.name,
    summary: summary ?? this.summary,
    isUserDefined: isUserDefined ?? this.isUserDefined,
    createdAt: createdAt,
  );
}

/// Represents a work session within a project
class Session {
  final String id;
  final String projectId;
  final String title;
  final DateTime startedAt;  // When current active period started
  final DateTime? endedAt;
  final String? notes;
  final List<String> filesModified;
  final SessionStatus status;
  final List<Map<String, dynamic>> conversationHistory;
  final Duration accumulatedDuration;  // Total time from previous open/close cycles
  
  // Topic & Summary fields (Phase 1)
  final List<SessionTopic> topics;     // AI-detected + user-defined topics
  final String? summary;                // AI-generated session summary
  final List<String> keyDecisions;      // Important decisions made

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
    this.accumulatedDuration = Duration.zero,
    List<SessionTopic>? topics,
    this.summary,
    List<String>? keyDecisions,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now(),
        filesModified = filesModified ?? [],
        conversationHistory = conversationHistory ?? [],
        topics = topics ?? [],
        keyDecisions = keyDecisions ?? [];

  /// Calculate total session duration (accumulated + current period)
  /// 
  /// For completed sessions: accumulated + (endedAt - startedAt)
  /// For active sessions: accumulated + (now - startedAt)
  Duration get duration {
    // If session is completed but endedAt is missing (corrupted data),
    // return just accumulated duration
    if (status == SessionStatus.completed && endedAt == null) {
      return accumulatedDuration;
    }
    // Calculate current period duration
    final end = endedAt ?? DateTime.now();
    final currentPeriod = end.difference(startedAt);
    
    // Guard against negative durations (corrupted data where endedAt < startedAt)
    if (currentPeriod.isNegative) {
      return accumulatedDuration;
    }
    
    // Return accumulated + current
    return accumulatedDuration + currentPeriod;
  }

  bool get isActive => status == SessionStatus.inProgress;

  /// Use [clearEndedAt] = true to explicitly set endedAt to null
  Session copyWith({
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    String? notes,
    List<String>? filesModified,
    SessionStatus? status,
    List<Map<String, dynamic>>? conversationHistory,
    Duration? accumulatedDuration,
    List<SessionTopic>? topics,
    String? summary,
    bool clearSummary = false,
    List<String>? keyDecisions,
  }) {
    return Session(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      notes: notes ?? this.notes,
      filesModified: filesModified ?? this.filesModified,
      status: status ?? this.status,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      accumulatedDuration: accumulatedDuration ?? this.accumulatedDuration,
      topics: topics ?? this.topics,
      summary: clearSummary ? null : (summary ?? this.summary),
      keyDecisions: keyDecisions ?? this.keyDecisions,
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
      'accumulatedDurationMs': accumulatedDuration.inMilliseconds,
      'topics': topics.map((t) => t.toJson()).toList(),
      'summary': summary,
      'keyDecisions': keyDecisions,
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
      accumulatedDuration: Duration(milliseconds: json['accumulatedDurationMs'] as int? ?? 0),
      topics: (json['topics'] as List?)
          ?.map((t) => SessionTopic.fromJson(t as Map<String, dynamic>))
          .toList() ?? [],
      summary: json['summary'] as String?,
      keyDecisions: List<String>.from(json['keyDecisions'] ?? []),
    );
  }
}

enum SessionStatus {
  inProgress,
  completed,
  cancelled,
}
