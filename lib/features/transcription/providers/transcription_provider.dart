import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ai_provider.dart';
import '../../../core/providers/local_llm_providers.dart';
export '../../../core/providers/shared_preferences_provider.dart' show sharedPreferencesProvider;
import '../../../core/providers/shared_preferences_provider.dart';
import '../../recordings/models/recording.dart';
import '../../recordings/providers/recordings_provider.dart';
import '../../settings/providers/prompts_provider.dart';
import '../data/groq_transcription_service.dart';
import '../data/openai_chat_service.dart';
import '../models/transcription_state.dart';
import '../services/recording_service.dart';

// ── API key lookup ───────────────────────────────────────────────────────────

String _apiKeyFor(dynamic prefs, String id) =>
    prefs.getString('api_key_$id') ??
    (id == 'groq' ? prefs.getString('groq_api_key') : null) ??
    (id == 'openrouter' ? prefs.getString('openrouter_api_key') : null) ??
    '';

final groqApiKeyProvider = Provider<String>((ref) =>
    _apiKeyFor(ref.watch(sharedPreferencesProvider), 'groq'));

final apiKeyProvider = Provider<String>((ref) =>
    _apiKeyFor(ref.watch(sharedPreferencesProvider), 'openrouter'));

// ── Task model / provider selection ─────────────────────────────────────────

final transcribeModelProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('model_transcribe') ?? 'whisper-large-v3-turbo';
});

final refineModelProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('model_refine') ?? 'llama-3.3-70b-versatile';
});

final refineProviderIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('provider_refine') ?? 'groq';
});

final visionExtractModelProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('model_vision_extract') ?? 'qwen/qwen3.5-flash-02-23';
});

final visionMergeModelProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('model_vision_merge') ?? 'qwen/qwen3.5-flash-02-23';
});

final visionProviderIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('provider_vision') ?? 'openrouter';
});

// ── Polish settings ──────────────────────────────────────────────────────────

final polishThresholdSecondsProvider = Provider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getInt('polish_threshold_seconds') ?? 30;
});

// IDs of recordings currently being polished in the background
final polishingIdsProvider = StateProvider<Set<String>>((ref) => {});

// ID waiting for user confirmation before local-model polish
final pendingLocalPolishProvider = StateProvider<String?>((ref) => null);

// ── Service providers ────────────────────────────────────────────────────────

final groqTranscriptionProvider = Provider<GroqTranscriptionService>((ref) {
  final apiKey = ref.watch(groqApiKeyProvider);
  final transcribeModel = ref.watch(transcribeModelProvider);
  return GroqTranscriptionService(apiKey: apiKey, transcribeModel: transcribeModel);
});

final refineServiceProvider = Provider<OpenAiChatService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final providerId = ref.watch(refineProviderIdProvider);
  final provider = providerById(providerId);
  return OpenAiChatService(
    baseUrl: provider.baseUrl,
    apiKey: _apiKeyFor(prefs, providerId),
    model: ref.watch(refineModelProvider),
  );
});

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final service = RecordingService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Main state notifier ──────────────────────────────────────────────────────

class TranscriptionNotifier extends Notifier<TranscriptionState> {
  Timer? _recordingTimer;

  @override
  TranscriptionState build() {
    ref.onDispose(() => _recordingTimer?.cancel());
    return const TranscriptionState();
  }

  RecordingService get _recorder => ref.read(recordingServiceProvider);
  GroqTranscriptionService get _groq => ref.read(groqTranscriptionProvider);

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> toggleRecording() async {
    if (state.isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      state = state.copyWith(
        recordingStatus: RecordingStatus.recording,
        recordingSeconds: 0,
        clearError: true,
        clearAudio: true,
      );
      await _recorder.start();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        state = state.copyWith(recordingSeconds: state.recordingSeconds + 1);
      });
    } catch (e) {
      state = state.copyWith(
        recordingStatus: RecordingStatus.idle,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final durationSeconds = state.recordingSeconds;
    state = state.copyWith(recordingStatus: RecordingStatus.processing);

    try {
      final audioPath = await _recorder.stop();
      if (audioPath == null) throw Exception('No audio file produced');

      final rawText = await _groq.transcribe(audioPath);

      // Save immediately with raw text — polish happens asynchronously
      final recording = Recording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        durationSeconds: durationSeconds,
        audioPath: audioPath,
        rawText: rawText,
        polishedText: '',
      );
      await ref.read(recordingsProvider.notifier).add(recording);

      state = state.copyWith(
        rawText: rawText,
        recordingStatus: RecordingStatus.idle,
      );

      final threshold = ref.read(polishThresholdSecondsProvider);
      if (durationSeconds >= threshold) {
        _schedulePolish(recording);
      }
    } catch (e) {
      state = state.copyWith(
        recordingStatus: RecordingStatus.idle,
        errorMessage: 'Processing failed: $e',
      );
    }
  }

  void _schedulePolish(Recording recording) {
    if (ref.read(useLocalRefineProvider)) {
      ref.read(pendingLocalPolishProvider.notifier).state = recording.id;
    } else {
      _polishRecording(recording);
    }
  }

  Future<void> _polishRecording(Recording recording) async {
    ref.read(polishingIdsProvider.notifier).update((s) => {...s, recording.id});
    try {
      final activePrompt = ref.read(activePromptProvider);
      final polishedText = await ref.read(refineServiceProvider).refine(
        recording.rawText,
        systemPrompt: activePrompt.content,
      );
      await ref.read(recordingsProvider.notifier).update(
        recording.copyWith(polishedText: polishedText),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Polish failed: $e');
    } finally {
      ref.read(polishingIdsProvider.notifier)
          .update((s) => s.difference({recording.id}));
    }
  }

  // Manual polish trigger (from card "Clean Up" button)
  Future<void> polishRecording(String recordingId) async {
    final recording = ref
        .read(recordingsProvider)
        .cast<Recording?>()
        .firstWhere((r) => r?.id == recordingId, orElse: () => null);
    if (recording == null) return;

    if (ref.read(useLocalRefineProvider)) {
      ref.read(pendingLocalPolishProvider.notifier).state = recordingId;
      return;
    }
    await _polishRecording(recording);
  }

  // Called when user confirms local-model polish dialog
  Future<void> confirmLocalPolish(String recordingId) async {
    ref.read(pendingLocalPolishProvider.notifier).state = null;
    final recording = ref
        .read(recordingsProvider)
        .cast<Recording?>()
        .firstWhere((r) => r?.id == recordingId, orElse: () => null);
    if (recording == null) return;

    ref.read(polishingIdsProvider.notifier)
        .update((s) => {...s, recordingId});
    try {
      final activePrompt = ref.read(activePromptProvider);
      final polishedText = await ref.read(localRefineServiceProvider).refine(
        recording.rawText,
        systemPrompt: activePrompt.content,
      );
      await ref.read(recordingsProvider.notifier).update(
        recording.copyWith(polishedText: polishedText),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Polish failed: $e');
    } finally {
      ref.read(polishingIdsProvider.notifier)
          .update((s) => s.difference({recordingId}));
    }
  }

  void declineLocalPolish() {
    ref.read(pendingLocalPolishProvider.notifier).state = null;
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  void setEditMode(EditMode mode) => state = state.copyWith(editMode: mode);
  void updateRawText(String text) => state = state.copyWith(rawText: text);
  void updatePolishedText(String text) =>
      state = state.copyWith(polishedText: text);

  // ── Expansion ──────────────────────────────────────────────────────────────

  void toggleRawExpanded() =>
      state = state.copyWith(isRawExpanded: !state.isRawExpanded);

  void togglePolishedExpanded() =>
      state = state.copyWith(isPolishedExpanded: !state.isPolishedExpanded);

  // ── Checkboxes ─────────────────────────────────────────────────────────────

  void setExportRaw(bool value) => state = state.copyWith(exportRaw: value);
  void setExportPolished(bool value) =>
      state = state.copyWith(exportPolished: value);
  void setExportAudio(bool value) =>
      state = state.copyWith(exportAudio: value);

  // ── Clipboard ──────────────────────────────────────────────────────────────

  Future<void> copyToClipboard() async {
    final buffer = StringBuffer();
    if (state.exportRaw && state.rawText.isNotEmpty) {
      buffer.writeln('# Raw\n${state.rawText}\n');
    }
    if (state.exportPolished && state.polishedText.isNotEmpty) {
      buffer.writeln('# Polished\n${state.polishedText}\n');
    }
    if (state.exportAudio && state.audioPath != null) {
      buffer.write('![[audio_link.opus]]');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  void clearError() => state = state.copyWith(clearError: true);
}

final transcriptionProvider =
    NotifierProvider<TranscriptionNotifier, TranscriptionState>(
  TranscriptionNotifier.new,
);
