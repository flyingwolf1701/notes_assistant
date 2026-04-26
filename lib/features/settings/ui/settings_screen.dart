import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_keys_screen.dart';
import 'download_model_screen.dart';
import 'models_config_screen.dart';
import 'prompts_screen.dart';
import '../../transcription/ui/widgets/action_bar.dart';
import '../../transcription/providers/transcription_provider.dart';
import '../../../core/widgets/notes_app_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const NotesAppBar(),
      bottomNavigationBar: const SafeArea(top: false, child: ActionBar()),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('API Keys'),
            subtitle: const Text('Groq and OpenRouter keys'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Refinement Prompts'),
            subtitle: const Text('Prompts used to polish transcriptions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PromptsScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('Configure Models'),
            subtitle: const Text('Model IDs for transcription and vision'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModelsConfigScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download On-device Model'),
            subtitle: const Text('Gemma 4 for local image transcription'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadModelScreen()),
            ),
          ),
          const Divider(height: 1),
          _PolishThresholdTile(),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _PolishThresholdTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = ref.watch(polishThresholdSecondsProvider);

    return ListTile(
      leading: const Icon(Icons.auto_fix_high),
      title: const Text('Auto-polish threshold'),
      subtitle: Text(
        threshold == 0
            ? 'Always auto-polish'
            : 'Auto-polish recordings over $threshold seconds',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThresholdDialog(context, ref, threshold),
    );
  }

  Future<void> _showThresholdDialog(
      BuildContext context, WidgetRef ref, int current) async {
    int value = current;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Auto-polish threshold'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value == 0
                    ? 'Always auto-polish'
                    : 'Polish recordings over $value seconds',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              Slider(
                value: value.toDouble(),
                min: 0,
                max: 180,
                divisions: 18,
                label: value == 0 ? 'Always' : '${value}s',
                onChanged: (v) => setState(() => value = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(sharedPreferencesProvider)
                    .setInt('polish_threshold_seconds', value);
                ref.invalidate(polishThresholdSecondsProvider);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
