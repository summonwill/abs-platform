import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiKeys = ref.watch(aiKeysProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: 'AI Integration',
            children: [
              _APIKeyTile(
                title: 'OpenAI API Key',
                subtitle: 'For GPT-4o access',
                icon: Icons.psychology,
                provider: 'openai',
                hasKey: aiKeys.openAI != null,
                currentKey: aiKeys.openAI,
              ),
              _APIKeyTile(
                title: 'Anthropic API Key',
                subtitle: 'For Claude access',
                icon: Icons.smart_toy,
                provider: 'anthropic',
                hasKey: aiKeys.anthropic != null,
                currentKey: aiKeys.anthropic,
              ),
              _APIKeyTile(
                title: 'Google Gemini API Key',
                subtitle: 'For Gemini access',
                icon: Icons.auto_awesome,
                provider: 'gemini',
                hasKey: aiKeys.gemini != null,
                currentKey: aiKeys.gemini,
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.verified),
                title: const Text('ABS Studio'),
                subtitle: const Text('About AI-Based Software methodology'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.verified, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('About ABS Studio'),
                        ],
                      ),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI-Based Software (ABS) Platform',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ABS is a methodology for AI-assisted software development that uses governance files to maintain context and consistency across AI interactions.',
                          ),
                          SizedBox(height: 16),
                          Text('Key Features:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('• Governance file management'),
                          Text('• Multi-provider AI support'),
                          Text('• Session tracking'),
                          Text('• File operations via AI'),
                        ],
                      ),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Open source licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(context: context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}

class _APIKeyTile extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String provider;
  final bool hasKey;
  final String? currentKey;

  const _APIKeyTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.provider,
    required this.hasKey,
    this.currentKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasKey)
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(hasKey ? Icons.edit : Icons.add),
            onPressed: () => _showAPIKeyDialog(context, ref),
            tooltip: hasKey ? 'Edit API key' : 'Add API key',
          ),
          if (hasKey)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteAPIKey(context, ref),
              tooltip: 'Delete API key',
            ),
        ],
      ),
    );
  }

  Future<void> _showAPIKeyDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: currentKey);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hasKey ? 'Edit $title' : 'Add $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your API key is stored locally and never sent anywhere except to the AI provider.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                hintText: 'sk-...',
              ),
              obscureText: true,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (provider == 'openai') {
        await ref.read(aiKeysProvider.notifier).saveKeys(openAI: result);
      } else if (provider == 'anthropic') {
        await ref.read(aiKeysProvider.notifier).saveKeys(anthropic: result);
      } else if (provider == 'gemini') {
        await ref.read(aiKeysProvider.notifier).saveKeys(gemini: result);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title saved successfully')),
        );
      }
    }
  }

  Future<void> _deleteAPIKey(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key'),
        content: Text('Are you sure you want to delete your $title?'),
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
      await ref.read(aiKeysProvider.notifier).clearKey(provider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title deleted')),
        );
      }
    }
  }
}
