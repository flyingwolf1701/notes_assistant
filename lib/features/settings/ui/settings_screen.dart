import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../image_transcription/providers/image_transcription_provider.dart';
import '../../transcription/providers/transcription_provider.dart';
import '../models/prompt.dart';
import '../providers/prompts_provider.dart';
import 'prompt_edit_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _openRouterController;
  late final TextEditingController _groqController;
  bool _obscureOpenRouter = true;
  bool _obscureGroq = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _openRouterController = TextEditingController(text: ref.read(apiKeyProvider));
    _groqController = TextEditingController(text: ref.read(groqApiKeyProvider));
  }

  @override
  void dispose() {
    _openRouterController.dispose();
    _groqController.dispose();
    super.dispose();
  }

  Future<void> _saveKeys() async {
    // ignore: avoid_print
    print('DEBUG _groqController.text="${_groqController.text}" .trim()="${_groqController.text.trim()}"');
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('openrouter_api_key', _openRouterController.text.trim());
    await prefs.setString('groq_api_key', _groqController.text.trim());
    // ignore: avoid_print
    print('DEBUG saved groq key length=${_groqController.text.trim().length} readback=${prefs.getString('groq_api_key')?.length}');
    ref.invalidate(apiKeyProvider);
    ref.invalidate(groqApiKeyProvider);
    ref.invalidate(processingRepositoryProvider);
    ref.invalidate(groqTranscriptionProvider);
    ref.invalidate(visionServiceProvider);
    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompts = ref.watch(promptsProvider);
    final selectedId = ref.watch(selectedPromptIdProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── API Keys ──────────────────────────────────────────────────
          Text('Groq API Key (Transcription)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Used for Whisper voice-to-text',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          TextField(
            controller: _groqController,
            obscureText: _obscureGroq,
            decoration: InputDecoration(
              hintText: 'gsk_...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureGroq ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureGroq = !_obscureGroq),
              ),
            ),
            onChanged: (_) => setState(() => _saved = false),
          ),
          const SizedBox(height: 24),
          Text('OpenRouter API Key (Image transcription)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Used for image-to-text via GPT-4o',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          TextField(
            controller: _openRouterController,
            obscureText: _obscureOpenRouter,
            decoration: InputDecoration(
              hintText: 'sk-or-...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureOpenRouter ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureOpenRouter = !_obscureOpenRouter),
              ),
            ),
            onChanged: (_) => setState(() => _saved = false),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saveKeys,
            child: Text(_saved ? 'Saved!' : 'Save API Keys'),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Refinement Prompts ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text('Refinement Prompts',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PromptEditScreen()),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Select which prompt is used to polish transcriptions',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),

          ...prompts.map((prompt) {
            final isSelected = prompt.id == selectedId;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Radio<String>(
                  value: prompt.id,
                  groupValue: selectedId,
                  onChanged: (id) async {
                    if (id == null) return;
                    final prefs = ref.read(sharedPreferencesProvider);
                    await prefs.setString('selected_prompt_id', id);
                    ref.invalidate(selectedPromptIdProvider);
                  },
                ),
                title: Text(prompt.name,
                    style: isSelected
                        ? TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary)
                        : null),
                subtitle: Text(
                  prompt.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PromptEditScreen(existing: prompt)),
                      ),
                    ),
                    if (prompt.id != defaultPrompt.id)
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: scheme.error),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete prompt?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(promptsProvider.notifier)
                                .delete(prompt.id);
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
