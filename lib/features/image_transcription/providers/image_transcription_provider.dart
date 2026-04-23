import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/ai_provider.dart';
import '../../transcription/providers/transcription_provider.dart'
    show sharedPreferencesProvider, visionExtractModelProvider, visionMergeModelProvider, visionProviderIdProvider;
import '../../../core/providers/local_llm_providers.dart';
import '../services/vision_service.dart';
import '../services/vision_service_base.dart';

enum ImageSessionStatus { idle, capturing, processing, done, error }

class ImageSessionState {
  const ImageSessionState({
    this.status = ImageSessionStatus.idle,
    this.imagePaths = const [],
    this.extractedTexts = const [],
    this.mergedMarkdown = '',
    this.processingIndex = 0,
    this.errorMessage,
  });

  final ImageSessionStatus status;
  final List<String> imagePaths;
  final List<String> extractedTexts;
  final String mergedMarkdown;
  final int processingIndex;
  final String? errorMessage;

  bool get isProcessing => status == ImageSessionStatus.processing;
  bool get isDone => status == ImageSessionStatus.done;

  String get progressLabel {
    if (status != ImageSessionStatus.processing) return '';
    if (processingIndex < imagePaths.length) {
      return 'Reading image ${processingIndex + 1} of ${imagePaths.length}…';
    }
    return 'Merging pages…';
  }

  ImageSessionState copyWith({
    ImageSessionStatus? status,
    List<String>? imagePaths,
    List<String>? extractedTexts,
    String? mergedMarkdown,
    int? processingIndex,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ImageSessionState(
      status: status ?? this.status,
      imagePaths: imagePaths ?? this.imagePaths,
      extractedTexts: extractedTexts ?? this.extractedTexts,
      mergedMarkdown: mergedMarkdown ?? this.mergedMarkdown,
      processingIndex: processingIndex ?? this.processingIndex,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final visionServiceProvider = Provider<VisionService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final providerId = ref.watch(visionProviderIdProvider);
  final provider = providerById(providerId);
  final apiKey = prefs.getString('api_key_$providerId') ??
      (providerId == 'groq' ? prefs.getString('groq_api_key') : null) ??
      (providerId == 'openrouter' ? prefs.getString('openrouter_api_key') : null) ??
      '';
  final extractModel = ref.watch(visionExtractModelProvider);
  final mergeModel = ref.watch(visionMergeModelProvider);
  return VisionService(
    apiKey: apiKey,
    baseUrl: provider.baseUrl,
    extractModel: extractModel,
    mergeModel: mergeModel,
  );
});

final activeVisionServiceProvider = Provider<VisionServiceBase>((ref) {
  if (ref.watch(useLocalVisionProvider)) return ref.watch(localVisionServiceProvider);
  return ref.watch(visionServiceProvider);
});

class ImageTranscriptionNotifier extends Notifier<ImageSessionState> {
  @override
  ImageSessionState build() => const ImageSessionState();

  void addImage(String path) {
    state = state.copyWith(
      imagePaths: [...state.imagePaths, path],
      status: ImageSessionStatus.capturing,
    );
  }

  void removeImage(int index) {
    final paths = [...state.imagePaths]..removeAt(index);
    state = state.copyWith(
      imagePaths: paths,
      status: paths.isEmpty ? ImageSessionStatus.idle : ImageSessionStatus.capturing,
    );
  }

  void reset() => state = const ImageSessionState();

  Future<void> processImages() async {
    if (state.imagePaths.isEmpty) return;

    state = state.copyWith(
      status: ImageSessionStatus.processing,
      extractedTexts: [],
      processingIndex: 0,
      clearError: true,
    );

    final service = ref.read(activeVisionServiceProvider);
    final extractions = <String>[];

    try {
      for (var i = 0; i < state.imagePaths.length; i++) {
        state = state.copyWith(processingIndex: i);
        final text = await service.extractFromImage(state.imagePaths[i]);
        extractions.add(text);
        state = state.copyWith(extractedTexts: List.unmodifiable(extractions));
      }

      state = state.copyWith(
          processingIndex: state.imagePaths.length); // "Merging…" label
      final merged = await service.mergeExtractions(extractions);

      state = state.copyWith(
        status: ImageSessionStatus.done,
        mergedMarkdown: merged,
      );
    } catch (e) {
      state = state.copyWith(
        status: ImageSessionStatus.error,
        errorMessage: 'Processing failed: $e',
      );
    }
  }

  void resolveCandidates(String resolved) {
    state = state.copyWith(mergedMarkdown: resolved);
  }
}

final imageTranscriptionProvider =
    NotifierProvider<ImageTranscriptionNotifier, ImageSessionState>(
  ImageTranscriptionNotifier.new,
);
