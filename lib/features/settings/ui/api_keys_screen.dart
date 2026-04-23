import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/ai_provider.dart';
import '../../image_transcription/providers/image_transcription_provider.dart';
import '../../transcription/providers/transcription_provider.dart';

class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  late final Map<String, TextEditingController> _controllers;
  final Map<String, bool> _obscured = {};
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _controllers = {
      for (final p in kKnownProviders)
        p.id: TextEditingController(
          text: prefs.getString('api_key_${p.id}') ??
              (p.id == 'groq' ? prefs.getString('groq_api_key') : null) ??
              (p.id == 'openrouter' ? prefs.getString('openrouter_api_key') : null) ??
              '',
        ),
    };
    for (final p in kKnownProviders) {
      _obscured[p.id] = true;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveKeys() async {
    final prefs = ref.read(sharedPreferencesProvider);
    for (final p in kKnownProviders) {
      await prefs.setString('api_key_${p.id}', _controllers[p.id]!.text.trim());
    }
    ref.invalidate(groqApiKeyProvider);
    ref.invalidate(apiKeyProvider);
    ref.invalidate(groqTranscriptionProvider);
    ref.invalidate(refineServiceProvider);
    ref.invalidate(visionServiceProvider);
    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API keys saved'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Keys'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final p in kKnownProviders) ...[
            Text(p.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(p.baseUrl, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: _controllers[p.id],
              obscureText: _obscured[p.id]!,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscured[p.id]! ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscured[p.id] = !_obscured[p.id]!),
                ),
              ),
              onChanged: (_) => setState(() => _saved = false),
            ),
            const SizedBox(height: 20),
          ],
          FilledButton(
            onPressed: _saveKeys,
            child: Text(_saved ? 'Saved!' : 'Save Keys'),
          ),
        ],
      ),
    );
  }
}
