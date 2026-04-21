import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prompt.dart';
import '../providers/prompts_provider.dart';

class PromptEditScreen extends ConsumerStatefulWidget {
  const PromptEditScreen({super.key, this.existing});
  final Prompt? existing;

  @override
  ConsumerState<PromptEditScreen> createState() => _PromptEditScreenState();
}

class _PromptEditScreenState extends ConsumerState<PromptEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contentCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (name.isEmpty || content.isEmpty) return;

    final notifier = ref.read(promptsProvider.notifier);
    if (widget.existing != null) {
      await notifier.update(widget.existing!.copyWith(name: name, content: content));
    } else {
      await notifier.add(Prompt(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        content: content,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = widget.existing?.id == defaultPrompt.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Prompt' : 'Edit Prompt'),
        centerTitle: true,
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentCtrl,
            maxLines: null,
            minLines: 6,
            decoration: const InputDecoration(
              labelText: 'Prompt content',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (isDefault)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The default prompt can be edited but not deleted.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
