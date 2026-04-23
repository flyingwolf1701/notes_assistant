import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/ai_provider.dart';
import '../../../core/providers/local_llm_providers.dart';
import '../../transcription/providers/transcription_provider.dart';
import '../../image_transcription/providers/image_transcription_provider.dart';

const _cloudVisionOptions = [
  _ModelOption('Qwen3 Flash', 'qwen/qwen3.5-flash-02-23'),
  _ModelOption('Llama 4 Scout', 'meta-llama/llama-4-scout-17b-16e-instruct'),
];

class _ModelOption {
  const _ModelOption(this.label, this.modelId);
  final String label;
  final String modelId;
}

const _kCustom = 'custom';
const _kGemma = 'gemma_local';

class ModelsConfigScreen extends ConsumerStatefulWidget {
  const ModelsConfigScreen({super.key});

  @override
  ConsumerState<ModelsConfigScreen> createState() => _ModelsConfigScreenState();
}

class _ModelsConfigScreenState extends ConsumerState<ModelsConfigScreen> {
  late final TextEditingController _transcribeCtrl;
  late final TextEditingController _refineCtrl;
  late final TextEditingController _customExtractCtrl;
  late final TextEditingController _customMergeCtrl;

  late bool _refineIsLocal;
  late String _refineProviderId;
  late String _selectedVision;
  late String _visionProviderId;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _transcribeCtrl = TextEditingController(text: ref.read(transcribeModelProvider));
    _refineCtrl = TextEditingController(text: ref.read(refineModelProvider));
    _refineIsLocal = ref.read(useLocalRefineProvider);
    _refineProviderId = ref.read(refineProviderIdProvider);
    _visionProviderId = ref.read(visionProviderIdProvider);

    final currentExtract = ref.read(visionExtractModelProvider);
    _customExtractCtrl = TextEditingController(text: currentExtract);
    _customMergeCtrl = TextEditingController(text: ref.read(visionMergeModelProvider));

    if (ref.read(useLocalVisionProvider)) {
      _selectedVision = _kGemma;
    } else if (_cloudVisionOptions.any((o) => o.modelId == currentExtract)) {
      _selectedVision = currentExtract;
    } else {
      _selectedVision = _kCustom;
    }
  }

  @override
  void dispose() {
    _transcribeCtrl.dispose();
    _refineCtrl.dispose();
    _customExtractCtrl.dispose();
    _customMergeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('model_transcribe', _transcribeCtrl.text.trim());
    await prefs.setBool('use_local_refine', _refineIsLocal);
    await prefs.setString('provider_refine', _refineProviderId);
    await prefs.setString('model_refine', _refineCtrl.text.trim());

    final useLocalVision = _selectedVision == _kGemma;
    await prefs.setBool('use_local_vision', useLocalVision);
    await prefs.setString('provider_vision', _visionProviderId);

    if (!useLocalVision) {
      if (_selectedVision == _kCustom) {
        await prefs.setString('model_vision_extract', _customExtractCtrl.text.trim());
        await prefs.setString('model_vision_merge', _customMergeCtrl.text.trim());
      } else {
        // Preset: use the same model for extract and merge.
        await prefs.setString('model_vision_extract', _selectedVision);
        await prefs.setString('model_vision_merge', _selectedVision);
      }
    }

    ref.invalidate(transcribeModelProvider);
    ref.invalidate(useLocalRefineProvider);
    ref.invalidate(refineProviderIdProvider);
    ref.invalidate(refineModelProvider);
    ref.invalidate(refineServiceProvider);
    ref.invalidate(groqTranscriptionProvider);
    ref.invalidate(useLocalVisionProvider);
    ref.invalidate(visionProviderIdProvider);
    ref.invalidate(visionExtractModelProvider);
    ref.invalidate(visionMergeModelProvider);
    ref.invalidate(visionServiceProvider);

    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), duration: Duration(seconds: 2)),
      );
    }
  }

  Widget _textField(String label, String hint, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
          onChanged: (_) => setState(() => _saved = false),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _providerDropdown(String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      items: [
        for (final p in kKnownProviders)
          DropdownMenuItem(value: p.id, child: Text(p.name)),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = ref.watch(modelDownloadedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configure Models'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Voice Transcription ──────────────────────────────────────────
          Text('Voice Transcription', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _textField('Transcribe model (Groq / Whisper)', 'whisper-large-v3-turbo', _transcribeCtrl),

          Text('Refine / cleanup', style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),

          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gemma 4 (on-device)'),
            subtitle: Text(
              downloaded.when(
                data: (ok) => ok ? 'Downloaded & ready' : 'Not downloaded — use Download Model',
                loading: () => 'Checking…',
                error: (_, __) => '',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: true,
            groupValue: _refineIsLocal,
            onChanged: (v) => setState(() { _refineIsLocal = v!; _saved = false; }),
          ),

          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cloud model'),
            value: false,
            groupValue: _refineIsLocal,
            onChanged: (v) => setState(() { _refineIsLocal = v!; _saved = false; }),
          ),

          if (!_refineIsLocal) ...[
            const SizedBox(height: 4),
            _providerDropdown(
              _refineProviderId,
              (v) => setState(() { _refineProviderId = v!; _saved = false; }),
            ),
            const SizedBox(height: 12),
            _textField('Refine model', 'llama-3.3-70b-versatile', _refineCtrl),
          ] else
            const SizedBox(height: 12),

          const Divider(),
          const SizedBox(height: 12),

          // ── Image Transcription ──────────────────────────────────────────
          Text('Image Transcription', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gemma 4 (on-device)'),
            subtitle: Text(
              downloaded.when(
                data: (ok) => ok ? 'Downloaded & ready' : 'Not downloaded — use Download Model',
                loading: () => 'Checking…',
                error: (_, __) => '',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _kGemma,
            groupValue: _selectedVision,
            onChanged: (v) => setState(() { _selectedVision = v!; _saved = false; }),
          ),

          for (final opt in _cloudVisionOptions)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text(opt.label),
              value: opt.modelId,
              groupValue: _selectedVision,
              onChanged: (v) => setState(() { _selectedVision = v!; _saved = false; }),
            ),

          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Custom'),
            value: _kCustom,
            groupValue: _selectedVision,
            onChanged: (v) => setState(() { _selectedVision = v!; _saved = false; }),
          ),

          if (_selectedVision != _kGemma) ...[
            const SizedBox(height: 4),
            _providerDropdown(
              _visionProviderId,
              (v) => setState(() { _visionProviderId = v!; _saved = false; }),
            ),
            const SizedBox(height: 12),
          ],

          if (_selectedVision == _kCustom) ...[
            _textField('Extract model', 'model-id', _customExtractCtrl),
            _textField('Merge model', 'model-id', _customMergeCtrl),
          ],

          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: Text(_saved ? 'Saved!' : 'Save')),
        ],
      ),
    );
  }
}
