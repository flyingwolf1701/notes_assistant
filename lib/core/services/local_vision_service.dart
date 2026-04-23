import 'dart:io';
import '../../features/image_transcription/services/vision_service_base.dart';
import 'model_downloader_service.dart';
import 'local_llm_service.dart';

const _extractPrompt = '''
Extract all text from this image and format it as Markdown.
Rules:
- Preserve headings, lists, and paragraph structure where visible
- For words you cannot read clearly due to handwriting or image quality,
  write them as {option1|option2|option3} with your best guesses as options
- Do not add commentary — output only the extracted Markdown text
''';

const _mergePrompt = '''
The following are Markdown text extractions from multiple photos of the same document, taken in order.
Consecutive photos likely overlap — merge them into a single clean Markdown document by:
1. Detecting and removing duplicate/overlapping content between sections
2. Preserving the correct reading order
3. Keeping {option1|option2} uncertainty markers intact
4. Outputting only the final merged Markdown, no commentary
''';

class LocalVisionService implements VisionServiceBase {
  LocalVisionService({required this.llm, required this.downloader});

  final LocalLlmService llm;
  final ModelDownloaderService downloader;

  bool _engineReady = false;

  Future<void> _ensureEngine() async {
    if (_engineReady) return;

    final path = await downloader.modelPath();
    if (!await File(path).exists()) {
      throw Exception('Model not downloaded. Go to Settings → Download On-device Model.');
    }

    // Try GPU first, fall back to CPU if it fails.
    try {
      await llm.initEngine(modelPath: path, backend: 'gpu', systemPrompt: _extractPrompt);
    } catch (_) {
      await llm.initEngine(modelPath: path, backend: 'cpu', systemPrompt: _extractPrompt);
    }
    _engineReady = true;
  }

  @override
  Future<String> extractFromImage(String imagePath) async {
    await _ensureEngine();
    return llm.generate(text: _extractPrompt, imagePath: imagePath);
  }

  @override
  Future<String> mergeExtractions(List<String> extractions) async {
    if (extractions.length == 1) return extractions.first;
    await _ensureEngine();
    final numbered = extractions
        .asMap()
        .entries
        .map((e) => '## Photo ${e.key + 1}\n${e.value}')
        .join('\n\n---\n\n');
    return llm.generate(text: '$_mergePrompt\n\n$numbered');
  }

  void invalidate() => _engineReady = false;
}
