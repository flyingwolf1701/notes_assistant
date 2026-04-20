import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final processingRepositoryProvider = Provider<ProcessingRepository>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  return OpenRouterRepository(apiKey: apiKey);
});

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final service = RecordingService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Main state notifier ──────────────────────────────────────────────────────

class TranscriptionNotifier extends Notifier<TranscriptionState> {
  @override
  TranscriptionState build() {
    return const TranscriptionState();
  }

  RecordingService get _recorder => ref.read(recordingServiceProvider);
  ProcessingRepository get _repository => ref.read(processingRepositoryProvider);

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> toggleRecording() async {
    if (state.isRecording) {
      await _stopAndProcess();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      state = state.copyWith(
        recordingStatus: RecordingStatus.recording,
        clearError: true,
      );
      await _recorder.start();
    } catch (e) {
      state = state.copyWith(
        recordingStatus: RecordingStatus.idle,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  Future<void> _stopAndProcess() async {
    try {
      state = state.copyWith(recordingStatus: RecordingStatus.processing);

      final audioPath = await _recorder.stop();
      if (audioPath == null) throw Exception('No audio file produced');

      state = state.copyWith(audioPath: audioPath);

      // Transcribe
      final rawText = await _repository.transcribe(audioPath);
      state = state.copyWith(rawText: rawText);

      // Refine
      final polishedText = await _repository.refine(rawText);
      state = state.copyWith(
        polishedText: polishedText,
        recordingStatus: RecordingStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(
        recordingStatus: RecordingStatus.idle,
        errorMessage: 'Processing failed: $e',
      );
    }
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  /// Toggle a card into edit mode. Enforces the exclusive write lock.
  void setEditMode(EditMode mode) {
    state = state.copyWith(editMode: mode);
  }

  /// Save edited text back into state from a TextEditingController.
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
