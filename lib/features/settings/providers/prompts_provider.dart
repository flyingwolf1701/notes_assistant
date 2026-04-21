import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transcription/providers/transcription_provider.dart';
import '../models/prompt.dart';

const _kPromptsKey = 'prompts_v1';
const _kSelectedKey = 'selected_prompt_id';

class PromptsNotifier extends Notifier<List<Prompt>> {
  @override
  List<Prompt> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_kPromptsKey);
    if (raw == null) return [defaultPrompt];
    final list = jsonDecode(raw) as List<dynamic>;
    final prompts =
        list.map((e) => Prompt.fromJson(e as Map<String, dynamic>)).toList();
    // Always ensure default exists
    if (!prompts.any((p) => p.id == defaultPrompt.id)) {
      prompts.insert(0, defaultPrompt);
    }
    return prompts;
  }

  Future<void> _persist(List<Prompt> prompts) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
        _kPromptsKey, jsonEncode(prompts.map((p) => p.toJson()).toList()));
    state = prompts;
  }

  Future<void> add(Prompt prompt) => _persist([...state, prompt]);

  Future<void> update(Prompt prompt) => _persist([
        for (final p in state) p.id == prompt.id ? prompt : p,
      ]);

  Future<void> delete(String id) async {
    if (id == defaultPrompt.id) return;
    final updated = state.where((p) => p.id != id).toList();
    // If deleted prompt was selected, fall back to default
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getString(_kSelectedKey) == id) {
      await prefs.setString(_kSelectedKey, defaultPrompt.id);
      ref.invalidate(selectedPromptIdProvider);
    }
    await _persist(updated);
  }
}

final promptsProvider =
    NotifierProvider<PromptsNotifier, List<Prompt>>(PromptsNotifier.new);

final selectedPromptIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(_kSelectedKey) ?? defaultPrompt.id;
});

final activePromptProvider = Provider<Prompt>((ref) {
  final id = ref.watch(selectedPromptIdProvider);
  final prompts = ref.watch(promptsProvider);
  return prompts.firstWhere((p) => p.id == id, orElse: () => defaultPrompt);
});

Future<void> setSelectedPromptId(
    {required String id,
    required dynamic prefs,
    required dynamic ref}) async {
  await prefs.setString(_kSelectedKey, id);
  ref.invalidate(selectedPromptIdProvider);
}
