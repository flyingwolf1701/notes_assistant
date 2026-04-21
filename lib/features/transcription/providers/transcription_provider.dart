import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../recordings/models/recording.dart';
import '../../recordings/providers/recordings_provider.dart';
import '../../settings/providers/prompts_provider.dart';
import '../data/groq_transcription_service.dart';
import '../data/open_router_repository.dart';
import '../models/transcription_state.dart';
import '../services/processing_repository.dart';
import '../services/recording_service.dart';

// ── Infrastructure providers ─────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main() via ProviderScope overrides');
});

final apiKeyProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('openrouter_api_key') ?? '';
});

final groqApiKeyProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('groq_api_key') ?? '';
});

final processingRepositoryProvider = Provider<ProcessingRepository>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  return OpenRouterRepository(apiKey: apiKey);
});

final groqTranscriptionProvider = Provider<GroqTranscriptionService>((ref) {
  final apiKey = ref.watch(groqApiKeyProvider);
  return GroqTranscriptionService(apiKey: apiKey);
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
    try {
      state = state.copyWith(recordingStatus: RecordingStatus.processing);
      final audioPath = await _recorder.stop();
      if (audioPath == null) throw Exception('No audio file produced');
      state = state.copyWith(audioPath: audioPath);

      final key = ref.read(groqApiKeyProvider);
      // ignore: avoid_print
      print('DEBUG groq key length=${key.length} starts=${key.isEmpty ? "EMPTY" : key.substring(0, 4)}');
      final rawText = await _groq.transcribe(audioPath);
      state = state.copyWith(rawText: rawText);

      final activePrompt = ref.read(activePromptProvider);
      final polishedText = await _groq.refine(rawText, systemPrompt: activePrompt.content);
      state = state.copyWith(
        polishedText: polishedText,
        recordingStatus: RecordingStatus.idle,
      );

      final recording = Recording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        durationSeconds: durationSeconds,
        audioPath: audioPath,
        rawText: rawText,
        polishedText: polishedText,
      );
      await ref.read(recordingsProvider.notifier).add(recording);
    } catch (e) {
      state = state.copyWith(
        recordingStatus: RecordingStatus.idle,
        errorMessage: 'Processing failed: $e',
      );
    }
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
