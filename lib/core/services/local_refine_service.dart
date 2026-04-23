import 'dart:io';
import 'local_llm_service.dart';
import 'model_downloader_service.dart';

class LocalRefineService {
  LocalRefineService({required this.llm, required this.downloader});

  final LocalLlmService llm;
  final ModelDownloaderService downloader;

  Future<String> refine(String rawText, {required String systemPrompt}) async {
    final path = await downloader.modelPath();
    if (!await File(path).exists()) {
      throw Exception('Model not downloaded. Go to Settings → Download On-device Model.');
    }

    try {
      await llm.initEngine(modelPath: path, backend: 'gpu', systemPrompt: systemPrompt);
    } catch (_) {
      await llm.initEngine(modelPath: path, backend: 'cpu', systemPrompt: systemPrompt);
    }

    return llm.generate(text: rawText);
  }
}
