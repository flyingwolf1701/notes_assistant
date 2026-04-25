import 'package:flutter/material.dart';
import 'api_keys_screen.dart';
import 'download_model_screen.dart';
import 'models_config_screen.dart';
import 'prompts_screen.dart';
import '../../transcription/ui/widgets/action_bar.dart';
import '../../../core/widgets/notes_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
