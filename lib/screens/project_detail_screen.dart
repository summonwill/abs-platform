/// ABS Platform - Project Detail Screen
/// 
/// Purpose: Main project view displaying files, sessions, and AI chat access
/// Key Components:
///   - Files tab: Displays and allows editing of governance files
///   - Sessions tab: Lists work sessions with start/end functionality
///   - File viewer dialog: CodeEditor-based file editing with save capability
///   - AI chat window spawning: Creates separate OS windows for AI interaction
///   - File system watcher: Auto-refreshes file list when files change
/// 
/// Dependencies:
///   - desktop_multi_window: Separate window creation
///   - re_editor: Efficient large file editing
///   - project_provider: Project state management
/// 
/// Last Modified: December 6, 2025
library;

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../providers/project_provider.dart';
import '../providers/ai_provider.dart';
import '../models/project.dart';
import '../services/file_service.dart';
import '../services/debug_logger.dart';
import '../widgets/monaco_editor.dart';

/// Main project detail screen widget with file system watching
class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  StreamSubscription<FileSystemEvent>? _fileWatcher;
  Timer? _debounceTimer;
  String? _watchingPath;
  
  // Static flag to temporarily pause file watching during delete operations
  static bool pauseFileWatching = false;

  @override
  void dispose() {
    _fileWatcher?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _setupFileWatcher(String projectPath) {
    // Don't set up again if already watching this path
    if (_watchingPath == projectPath) return;
    
    // Cancel previous watcher
    _fileWatcher?.cancel();
    _watchingPath = projectPath;
    
    try {
      final directory = Directory(projectPath);
      if (directory.existsSync()) {
        // Watch recursively to catch changes in subfolders
        _fileWatcher = directory.watch(events: FileSystemEvent.all, recursive: true).listen((event) {
          // Skip if file watching is paused (during delete operations)
          if (pauseFileWatching) return;
          
          // React to common file types that AI might create/edit
          final path = event.path.toLowerCase();
          if (path.endsWith('.md') || 
              path.endsWith('.py') || 
              path.endsWith('.txt') ||
              path.endsWith('.json') ||
              path.endsWith('.yaml') ||
              path.endsWith('.yml') ||
              path.endsWith('.csv') ||
              path.endsWith('.bat') ||
              path.endsWith('.sh') ||
              path.endsWith('.ps1')) {
            print('DEBUG FileWatcher: ${event.type} - ${event.path}');
            _debouncedRefresh();
          }
        });
        print('DEBUG: File watcher set up for $projectPath (recursive)');
      }
    } catch (e) {
      print('DEBUG: Could not set up file watcher: $e');
    }
  }

  void _debouncedRefresh() {
    // Debounce to avoid multiple rapid refreshes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _refreshFiles();
    });
  }

  Future<void> _refreshFiles() async {
    final project = ref.read(selectedProjectProvider);
    if (project == null) return;
    
    final updatedProject = await ref.read(projectsProvider.notifier).refreshProjectFiles(project.id);
    if (updatedProject != null && mounted) {
      ref.read(selectedProjectProvider.notifier).state = updatedProject;
      print('DEBUG: Auto-refreshed file list - ${updatedProject.governanceFiles.length} files');
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(selectedProjectProvider);

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Details')),
        body: const Center(child: Text('No project selected')),
      );
    }

    // Set up file watcher when project changes
    _setupFileWatcher(project.path);

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
            onPressed: () => _showAIChatWindow(context, project, ref),
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
        onPressed: () => _showAIChatWindow(context, project, ref),
        icon: const Icon(Icons.chat_bubble),
        label: const Text('Chat with AI'),
        tooltip: 'Open AI Assistant',
      ),
    );
  }

  void _showAIChatWindow(BuildContext context, Project project, WidgetRef ref) async {
    // Get the notifier to check if loaded
    final notifier = ref.read(aiKeysProvider.notifier);
    
    // Wait for keys to load if not yet loaded (max 2 seconds)
    int attempts = 0;
    while (!notifier.isLoaded && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    // Get API keys to pass to separate window (separate windows can't access Hive)
    final aiKeys = ref.read(aiKeysProvider);
    
    // Debug: Check if keys are available
    print('DEBUG _showAIChatWindow:');
    print('  Keys loaded: ${notifier.isLoaded}');
    print('  OpenAI key present: ${aiKeys.openAI != null}');
    print('  Anthropic key present: ${aiKeys.anthropic != null}');
    print('  Gemini key present: ${aiKeys.gemini != null}');
    
    if (!aiKeys.hasAnyKey) {
      // Show warning if no keys configured
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No API keys configured. Please add keys in Settings first.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Create window arguments with project data AND API keys
    final windowArgs = {
      ...project.toJson(),
      'apiKeys': {
        'openai': aiKeys.openAI,
        'anthropic': aiKeys.anthropic,
        'gemini': aiKeys.gemini,
      },
    };
    
    final window = await DesktopMultiWindow.createWindow(jsonEncode(windowArgs));
    
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

class _FilesTab extends ConsumerStatefulWidget {
  final Project project;

  const _FilesTab({required this.project});

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  // Current directory path relative to project root (empty string = project root)
  String _currentPath = '';
  
  // Cache of directory contents
  Map<String, List<FileSystemEntity>> _directoryCache = {};
  bool _isLoading = false;
  
  // File watcher for auto-refresh
  StreamSubscription<FileSystemEvent>? _fileWatcher;
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentDirectory();
    _setupFileWatcher();
  }
  
  @override
  void dispose() {
    _fileWatcher?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  void _setupFileWatcher() {
    try {
      final directory = Directory(widget.project.path);
      if (directory.existsSync()) {
        _fileWatcher = directory.watch(events: FileSystemEvent.all, recursive: true).listen((event) {
          // Skip if file watching is paused (during delete operations)
          if (_ProjectDetailScreenState.pauseFileWatching) return;
          
          print('DEBUG FilesTab watcher: ${event.type} - ${event.path}');
          _debouncedReload();
        });
        print('DEBUG: FilesTab file watcher set up for ${widget.project.path}');
      }
    } catch (e) {
      print('DEBUG: Could not set up FilesTab file watcher: $e');
    }
  }
  
  void _debouncedReload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _directoryCache.clear(); // Clear cache to force reload
        _loadCurrentDirectory();
      }
    });
  }
  
  Future<void> _refreshFiles(BuildContext context) async {
    final updatedProject = await ref.read(projectsProvider.notifier).refreshProjectFiles(widget.project.id);
    if (updatedProject != null) {
      ref.read(selectedProjectProvider.notifier).state = updatedProject;
      _directoryCache.clear(); // Clear cache on refresh
      await _loadCurrentDirectory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Files refreshed')),
        );
      }
    }
  }
  
  Future<void> _loadCurrentDirectory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final fullPath = _currentPath.isEmpty 
          ? widget.project.path 
          : '${widget.project.path}${Platform.pathSeparator}${_currentPath.replaceAll('/', Platform.pathSeparator)}';
      
      final directory = Directory(fullPath);
      
      if (await directory.exists()) {
        final entities = await directory.list().toList();
        
        // Sort: folders first, then files, alphabetically
        entities.sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
        
        _directoryCache[_currentPath] = entities;
      }
    } catch (e) {
      print('Error loading directory: $e');
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }
  
  void _navigateToFolder(String folderName) {
    setState(() {
      if (_currentPath.isEmpty) {
        _currentPath = folderName;
      } else {
        _currentPath = '$_currentPath/$folderName';
      }
    });
    _loadCurrentDirectory();
  }
  
  void _navigateUp() {
    if (_currentPath.isEmpty) return; // Already at root
    
    setState(() {
      final lastSlash = _currentPath.lastIndexOf('/');
      if (lastSlash == -1) {
        _currentPath = ''; // Go to root
      } else {
        _currentPath = _currentPath.substring(0, lastSlash);
      }
    });
    _loadCurrentDirectory();
  }
  
  void _navigateToRoot() {
    setState(() {
      _currentPath = '';
    });
    _loadCurrentDirectory();
  }
  
  // Build breadcrumb path segments
  List<String> _getBreadcrumbs() {
    if (_currentPath.isEmpty) return [];
    return _currentPath.split('/');
  }
  
  void _navigateToBreadcrumb(int index) {
    final breadcrumbs = _getBreadcrumbs();
    if (index < 0) {
      _navigateToRoot();
    } else {
      setState(() {
        _currentPath = breadcrumbs.sublist(0, index + 1).join('/');
      });
      _loadCurrentDirectory();
    }
  }
  
  // Show dialog to create a new folder
  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'Enter folder name',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      await _createFolder(result);
    }
  }
  
  // Show dialog to create a new file
  Future<void> _showCreateFileDialog(BuildContext context, String extension) async {
    final controller = TextEditingController();
    String selectedExt = extension;
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'File name',
                  hintText: extension.isEmpty ? 'filename.ext' : 'filename',
                  suffixText: selectedExt.isNotEmpty ? selectedExt : null,
                ),
                onSubmitted: (value) => Navigator.pop(context, {'name': value, 'ext': selectedExt}),
              ),
              if (extension.isEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedExt.isEmpty ? '.txt' : selectedExt,
                  decoration: const InputDecoration(labelText: 'File type'),
                  items: const [
                    DropdownMenuItem(value: '.txt', child: Text('Text (.txt)')),
                    DropdownMenuItem(value: '.md', child: Text('Markdown (.md)')),
                    DropdownMenuItem(value: '.py', child: Text('Python (.py)')),
                    DropdownMenuItem(value: '.json', child: Text('JSON (.json)')),
                    DropdownMenuItem(value: '.csv', child: Text('CSV (.csv)')),
                    DropdownMenuItem(value: '.yaml', child: Text('YAML (.yaml)')),
                    DropdownMenuItem(value: '.html', child: Text('HTML (.html)')),
                    DropdownMenuItem(value: '.js', child: Text('JavaScript (.js)')),
                    DropdownMenuItem(value: '.bat', child: Text('Batch (.bat)')),
                    DropdownMenuItem(value: '.ps1', child: Text('PowerShell (.ps1)')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedExt = value ?? '.txt'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {'name': controller.text, 'ext': selectedExt}),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null && result['name']!.isNotEmpty) {
      String fileName = result['name']!;
      final ext = result['ext']!;
      
      // Add extension if not already present
      if (ext.isNotEmpty && !fileName.contains('.')) {
        fileName = '$fileName$ext';
      }
      
      await _createFile(fileName);
    }
  }
  
  // Create a new folder in the current directory
  Future<void> _createFolder(String name) async {
    try {
      final relativePath = _currentPath.isEmpty ? name : '$_currentPath/$name';
      final fullPath = '${widget.project.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
      
      final dir = Directory(fullPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created folder: $name')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder already exists: $name'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating folder: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  // Create a new file in the current directory
  Future<void> _createFile(String name) async {
    try {
      final relativePath = _currentPath.isEmpty ? name : '$_currentPath/$name';
      final fullPath = '${widget.project.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
      
      final file = File(fullPath);
      if (!await file.exists()) {
        // Create with default content based on file type
        String content = '';
        if (name.endsWith('.md')) {
          content = '# ${name.replaceAll('.md', '')}\n\n';
        } else if (name.endsWith('.py')) {
          content = '# ${name.replaceAll('.py', '')}\n\n';
        } else if (name.endsWith('.json')) {
          content = '{\n  \n}\n';
        } else if (name.endsWith('.html')) {
          content = '<!DOCTYPE html>\n<html>\n<head>\n  <title>$name</title>\n</head>\n<body>\n  \n</body>\n</html>\n';
        }
        
        await file.create(recursive: true);
        await file.writeAsString(content);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created file: $name')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File already exists: $name'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  // Show context menu for an item (right-click)
  void _showItemContextMenu(BuildContext context, Offset position, String name, String relativePath, bool isDirectory) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.open_in_new, size: 20),
            title: Text(isDirectory ? 'Open' : 'Edit'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            if (isDirectory) {
              _navigateToFolder(name);
            } else {
              _openFileViewer(context, widget.project, relativePath);
            }
          },
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.delete, size: 20, color: Colors.red[300]),
            title: Text('Delete', style: TextStyle(color: Colors.red[300])),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () => _confirmDelete(context, name, relativePath, isDirectory),
        ),
      ],
    );
  }
  
  // Show confirmation dialog before deleting
  Future<void> _confirmDelete(BuildContext context, String name, String relativePath, bool isDirectory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${isDirectory ? 'Folder' : 'File'}?'),
        content: Text(
          isDirectory 
              ? 'Are you sure you want to delete "$name" and ALL its contents?\n\nThis cannot be undone.'
              : 'Are you sure you want to delete "$name"?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deleteItem(relativePath, isDirectory);
    }
  }
  
  // Delete a file or folder
  Future<void> _deleteItem(String relativePath, bool isDirectory) async {
    try {
      final fileService = FileService();
      bool success;
      
      print('DEBUG _deleteItem: relativePath="$relativePath", isDirectory=$isDirectory');
      print('DEBUG _deleteItem: projectPath="${widget.project.path}"');
      
      // Pause all file watching and cancel watchers to release file handles
      print('DEBUG _deleteItem: Pausing file watchers...');
      _ProjectDetailScreenState.pauseFileWatching = true;
      await _fileWatcher?.cancel();
      _fileWatcher = null;
      
      // Give Windows time to release file handles
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (isDirectory) {
        success = await fileService.deleteProjectFolder(widget.project.path, relativePath);
      } else {
        success = await fileService.deleteProjectFile(widget.project.path, relativePath);
      }
      
      print('DEBUG _deleteItem: success=$success');
      
      // Resume file watching
      print('DEBUG _deleteItem: Resuming file watchers...');
      _ProjectDetailScreenState.pauseFileWatching = false;
      _setupFileWatcher();
      
      // Reload directory
      _directoryCache.clear();
      await _loadCurrentDirectory();
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted: $relativePath')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $relativePath'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('DEBUG _deleteItem: ERROR: $e');
      // Make sure watching is resumed even on error
      _ProjectDetailScreenState.pauseFileWatching = false;
      _setupFileWatcher();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final entities = _directoryCache[_currentPath] ?? [];
    final breadcrumbs = _getBreadcrumbs();
    final isAtRoot = _currentPath.isEmpty;

    return Column(
      children: [
        // Toolbar with breadcrumbs and refresh
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: isAtRoot ? null : _navigateUp,
                tooltip: 'Go up',
              ),
              // Home button
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: isAtRoot ? null : _navigateToRoot,
                tooltip: 'Go to project root',
              ),
              const SizedBox(width: 8),
              // Breadcrumb navigation
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Project root
                      InkWell(
                        onTap: isAtRoot ? null : _navigateToRoot,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_special,
                                size: 16,
                                color: isAtRoot 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                project.name,
                                style: TextStyle(
                                  fontWeight: isAtRoot ? FontWeight.bold : FontWeight.normal,
                                  color: isAtRoot 
                                      ? Theme.of(context).colorScheme.primary 
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Breadcrumb segments
                      for (var i = 0; i < breadcrumbs.length; i++) ...[
                        const Icon(Icons.chevron_right, size: 16),
                        InkWell(
                          onTap: i < breadcrumbs.length - 1 
                              ? () => _navigateToBreadcrumb(i) 
                              : null,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              breadcrumbs[i],
                              style: TextStyle(
                                fontWeight: i == breadcrumbs.length - 1 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                color: i == breadcrumbs.length - 1 
                                    ? Theme.of(context).colorScheme.primary 
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _refreshFiles(context),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 4),
              // Create new folder button
              IconButton(
                icon: const Icon(Icons.create_new_folder),
                onPressed: () => _showCreateFolderDialog(context),
                tooltip: 'New Folder',
              ),
              // Create new file button
              PopupMenuButton<String>(
                icon: const Icon(Icons.add),
                tooltip: 'New File',
                onSelected: (value) => _showCreateFileDialog(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: '.txt', child: Text('Text File (.txt)')),
                  const PopupMenuItem(value: '.md', child: Text('Markdown (.md)')),
                  const PopupMenuItem(value: '.py', child: Text('Python (.py)')),
                  const PopupMenuItem(value: '.json', child: Text('JSON (.json)')),
                  const PopupMenuItem(value: '.csv', child: Text('CSV (.csv)')),
                  const PopupMenuItem(value: '', child: Text('Custom...')),
                ],
              ),
            ],
          ),
        ),
        // File list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : entities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Empty folder',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: entities.length,
                      itemBuilder: (context, index) {
                        final entity = entities[index];
                        final name = entity.path.split(Platform.pathSeparator).last;
                        final isDirectory = entity is Directory;
                        
                        // Skip hidden files/folders (starting with .)
                        if (name.startsWith('.')) {
                          return const SizedBox.shrink();
                        }
                        
                        // Build relative path for this item
                        final relativePath = _currentPath.isEmpty 
                            ? name 
                            : '$_currentPath/$name';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: InkWell(
                            onSecondaryTapUp: (details) {
                              _showItemContextMenu(
                                context, 
                                details.globalPosition, 
                                name, 
                                relativePath, 
                                isDirectory,
                              );
                            },
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                isDirectory ? Icons.folder : _getFileIcon(name),
                                color: isDirectory ? Colors.amber : _getFileIconColor(name),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: isDirectory ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Delete button
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                                    onPressed: () => _confirmDelete(context, name, relativePath, isDirectory),
                                    tooltip: 'Delete',
                                  ),
                                  Icon(
                                    isDirectory ? Icons.chevron_right : Icons.open_in_new,
                                    size: 20,
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (isDirectory) {
                                  _navigateToFolder(name);
                                } else {
                                  _openFileViewer(context, project, relativePath);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
  
  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.py')) return Icons.code;
    if (ext.endsWith('.md')) return Icons.description;
    if (ext.endsWith('.json') || ext.endsWith('.yaml') || ext.endsWith('.yml')) return Icons.data_object;
    if (ext.endsWith('.bat') || ext.endsWith('.sh') || ext.endsWith('.ps1')) return Icons.terminal;
    if (ext.endsWith('.csv')) return Icons.table_chart;
    if (ext.endsWith('.txt')) return Icons.article;
    if (ext.endsWith('.html') || ext.endsWith('.css') || ext.endsWith('.js')) return Icons.web;
    return Icons.insert_drive_file;
  }
  
  Color _getFileIconColor(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.py')) return Colors.blue;
    if (ext.endsWith('.md')) return Colors.orange;
    if (ext.endsWith('.json')) return Colors.yellow.shade700;
    if (ext.endsWith('.bat') || ext.endsWith('.sh') || ext.endsWith('.ps1')) return Colors.green;
    if (ext.endsWith('.csv')) return Colors.teal;
    return Colors.grey;
  }

  Future<void> _openFileViewer(BuildContext context, Project project, String filePath) async {
    final fileService = FileService();
    // Use readProjectFile which handles relative paths including subfolders
    final content = await fileService.readProjectFile(project.path, filePath);
    
    if (content == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read $filePath')),
        );
      }
      return;
    }

    // Open file in separate floating window with re_editor
    final fileData = jsonEncode({
      'windowType': 'file_editor',
      'fileName': filePath,
      'projectPath': project.path,
      'content': content,
    });
    
    final window = await DesktopMultiWindow.createWindow(fileData);
    window
      ..setTitle('$filePath - ${project.name}')
      ..setFrame(const Offset(100, 100) & const Size(1000, 700))
      ..center()
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

/// File editor dialog with Monaco
class _FileEditorDialog extends StatefulWidget {
  final String fileName;
  final String projectPath;
  final String initialContent;

  const _FileEditorDialog({
    required this.fileName,
    required this.projectPath,
    required this.initialContent,
  });

  @override
  State<_FileEditorDialog> createState() => _FileEditorDialogState();
}

class _FileEditorDialogState extends State<_FileEditorDialog> {
  late String _currentContent;
  bool _isModified = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentContent = widget.initialContent;
  }

  void _onContentChanged(String newContent) {
    setState(() {
      _currentContent = newContent;
      _isModified = newContent != widget.initialContent;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    
    final fileService = FileService();
    final success = await fileService.writeGovernanceFile(
      widget.projectPath,
      widget.fileName,
      _currentContent,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved successfully')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save file')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.description, size: 20),
              const SizedBox(width: 12),
              Text(widget.fileName),
              if (_isModified) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Modified',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (_isModified)
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save'),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (_isModified) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Unsaved Changes'),
                      content: const Text('Discard unsaved changes?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          child: const Text('Discard'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        body: MonacoEditor(
          initialContent: widget.initialContent,
          language: widget.fileName.endsWith('.md') ? 'markdown' : 'plaintext',
          onChanged: _onContentChanged,
        ),
      ),
    );
  }
}
