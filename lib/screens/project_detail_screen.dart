/// ABS Platform - Project Detail Screen
/// 
/// Purpose: Main project view displaying files, sessions, and AI chat access
/// Key Components:
///   - Files tab: Displays and allows editing of governance files
///   - Sessions tab: Lists work sessions with start/end functionality
///   - File viewer dialog: CodeEditor-based file editing with save capability
///   - AI chat window spawning: Creates separate OS windows for AI interaction
/// 
/// Dependencies:
///   - desktop_multi_window: Separate window creation
///   - re_editor: Efficient large file editing
///   - project_provider: Project state management
/// 
/// Last Modified: December 5, 2025

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';
import '../services/file_service.dart';
import '../services/debug_logger.dart';

/// Main project detail screen widget
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(selectedProjectProvider);

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Details')),
        body: const Center(child: Text('No project selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _exportForAI(context, ref, project),
            tooltip: 'Export for AI Conversation',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _showDebugLog(context),
            tooltip: 'View Debug Log',
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => _showAIChatWindow(context, project),
            tooltip: 'AI Assistant',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showProjectMenu(context, ref, project),
            tooltip: 'More options',
          ),
        ],
      ),
      body: Column(
        children: [
          _ProjectInfoCard(project: project),
          const Divider(height: 1),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.folder), text: 'Files'),
                      Tab(icon: Icon(Icons.history), text: 'Sessions'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _FilesTab(project: project),
                        _SessionsTab(project: project),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAIChatWindow(context, project),
        icon: const Icon(Icons.chat_bubble),
        label: const Text('Chat with AI'),
        tooltip: 'Open AI Assistant',
      ),
    );
  }

  void _showAIChatWindow(BuildContext context, Project project) async {
    // Create a new window with project data
    final projectJson = jsonEncode(project.toJson());
    final window = await DesktopMultiWindow.createWindow(projectJson);
    
    window
      ..setTitle('AI Assistant - ${project.name}')
      ..setFrame(const Offset(100, 100) & const Size(800, 600))
      ..setFrameAutosaveName('ai_chat_window')
      ..center()
      ..show();
  }

  Future<void> _showDebugLog(BuildContext context) async {
    final logContent = await DebugLogger.readLog();
    final logPath = await DebugLogger.getLogPath();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report),
            SizedBox(width: 8),
            Text('Debug Log'),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log file: ${logPath ?? "Unknown"}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      logContent,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logContent));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          if (logPath != null)
            TextButton(
              onPressed: () {
                Process.run('explorer', ['/select,', logPath]);
              },
              child: const Text('Open Folder'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportForAI(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final files = await ref.read(projectsProvider.notifier).exportForAI(project.id);

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No governance files to export')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => _ExportDialog(files: files, project: project),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _showProjectMenu(BuildContext context, WidgetRef ref, Project project) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Open in File Explorer'),
              onTap: () {
                Navigator.pop(context);
                Process.run('explorer', [project.path]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Project'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Edit project dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive Project'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Archive project
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Project', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteProject(context, ref, project);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?\n\n'
            'This will only remove the project from ABS. Files on disk will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(projectsProvider.notifier).deleteProject(project.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted project: ${project.name}')),
        );
      }
    }
  }
}

class _ProjectInfoCard extends StatelessWidget {
  final Project project;

  const _ProjectInfoCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project.description != null) ...[
              Text(
                project.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 16, 
                     color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.path,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.check_circle,
                  label: project.hasGovernanceFiles ? 'ABS Configured' : 'No ABS Files',
                  color: project.hasGovernanceFiles ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.description,
                  label: '${project.governanceFiles.length} files',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.history,
                  label: '${project.sessions.length} sessions',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilesTab extends StatelessWidget {
  final Project project;

  const _FilesTab({required this.project});

  @override
  Widget build(BuildContext context) {
    if (project.governanceFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No governance files found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                // TODO: Generate governance files
              },
              icon: const Icon(Icons.add),
              label: const Text('Generate ABS Files'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: project.governanceFiles.length,
      itemBuilder: (context, index) {
        final fileName = project.governanceFiles[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.description),
            title: Text(fileName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openFileViewer(context, project, fileName),
          ),
        );
      },
    );
  }

  Future<void> _openFileViewer(BuildContext context, Project project, String fileName) async {
    final fileService = FileService();
    final content = await fileService.readGovernanceFile(project.path, fileName);
    
    if (content == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read $fileName')),
        );
      }
      return;
    }

    // Open file in separate window
    final window = await DesktopMultiWindow.createWindow(jsonEncode({
      'windowType': 'file_editor',
      'fileName': fileName,
      'projectPath': project.path,
      'content': content,
    }));

    window
      ..setFrame(const Offset(100, 100) & const Size(1000, 700))
      ..setTitle('Edit: $fileName')
      ..show();
  }
}

class _SessionsTab extends ConsumerWidget {
  final Project project;

  const _SessionsTab({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (project.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No sessions yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _startNewSession(context, ref, project),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Session'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: project.sessions.length,
      itemBuilder: (context, index) {
        final session = project.sessions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              session.isActive ? Icons.radio_button_checked : Icons.check_circle_outline,
              color: session.isActive ? Colors.green : null,
            ),
            title: Text(session.title),
            subtitle: Text(
              '${_formatDate(session.startedAt)} • ${_formatDuration(session.duration)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open session details
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Future<void> _startNewSession(BuildContext context, WidgetRef ref, Project project) async {
    final controller = TextEditingController(text: 'Session ${project.sessions.length + 1}');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session Title',
            hintText: 'e.g., Feature Development, Bug Fixes',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      // Create session using provider
      await ref.read(projectsProvider.notifier).createSession(project.id, result);
      
      // Update selected project
      final updatedProject = ref.read(projectsProvider.notifier).getProject(project.id);
      if (updatedProject != null) {
        ref.read(selectedProjectProvider.notifier).state = updatedProject;
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session "$result" started')),
        );
      }
    }
  }
}

class _ExportDialog extends StatelessWidget {
  final Map<String, String> files;
  final Project project;

  const _ExportDialog({
    required this.files,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export for AI'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Copy these files to your AI conversation (ChatGPT, Claude, etc.)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final fileName = files.keys.elementAt(index);
                  final content = files[fileName]!;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: const Icon(Icons.description),
                      title: Text(fileName),
                      subtitle: Text('${content.split('\n').length} lines'),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    fileName,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  FilledButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: content));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Copied $fileName to clipboard')),
                                      );
                                    },
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    content,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            final combined = files.entries
                .map((e) => '=== ${e.key} ===\n\n${e.value}')
                .join('\n\n---\n\n');
            Clipboard.setData(ClipboardData(text: combined));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied all files to clipboard')),
            );
          },
          icon: const Icon(Icons.copy_all),
          label: const Text('Copy All'),
        ),
      ],
    );
  }
}
