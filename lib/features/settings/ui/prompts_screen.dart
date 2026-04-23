import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transcription/providers/transcription_provider.dart';
import '../models/prompt.dart';
import '../providers/prompts_provider.dart';
import 'prompt_edit_screen.dart';

class PromptsScreen extends ConsumerWidget {
  const PromptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompts = ref.watch(promptsProvider);
    final selectedId = ref.watch(selectedPromptIdProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refinement Prompts'),
        centerTitle: true,
        actions: [
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Select which prompt is used to polish transcriptions',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
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
                title: Text(
                  prompt.name,
                  style: isSelected
                      ? TextStyle(fontWeight: FontWeight.bold, color: scheme.primary)
                      : null,
                ),
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
                        icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete prompt?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(promptsProvider.notifier).delete(prompt.id);
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
