import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared_preferences_provider.dart';
import '../services/local_llm_service.dart';
import '../services/local_refine_service.dart';
import '../services/local_vision_service.dart';
import '../services/model_downloader_service.dart';

final modelDownloaderProvider = Provider<ModelDownloaderService>((_) => ModelDownloaderService());

final localLlmServiceProvider = Provider<LocalLlmService>((_) => LocalLlmService());

final localVisionServiceProvider = Provider<LocalVisionService>((ref) {
  return LocalVisionService(
    llm: ref.watch(localLlmServiceProvider),
    downloader: ref.watch(modelDownloaderProvider),
  );
});

final localRefineServiceProvider = Provider<LocalRefineService>((ref) {
  return LocalRefineService(
    llm: ref.watch(localLlmServiceProvider),
    downloader: ref.watch(modelDownloaderProvider),
  );
});

final useLocalVisionProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('use_local_vision') ?? false;
});

final useLocalRefineProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('use_local_refine') ?? false;
});

final modelDownloadedProvider = FutureProvider<bool>((ref) async {
  return ref.watch(modelDownloaderProvider).isDownloaded();
});
