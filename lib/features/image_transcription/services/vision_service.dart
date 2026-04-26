import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'vision_service_base.dart';

class VisionService implements VisionServiceBase {
  VisionService({
    required String apiKey,
    required String baseUrl,
    this.extractModel = 'meta-llama/llama-4-scout-17b-16e-instruct',
    this.mergeModel = 'llama-3.3-70b-versatile',
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $apiKey'},
          receiveTimeout: const Duration(seconds: 60),
        ));

  final Dio _dio;
  final String extractModel;
  final String mergeModel;

  static const _extractPrompt = '''
Extract all text from this image as Markdown. Read top-to-bottom, left-to-right.
- Use real Markdown headings only where the source uses headings
- Separate paragraphs with a blank line; do not use heading markers as dividers
- For illegible words write {option1|option2} with your best guesses
- Output only the extracted text. Stop immediately when all visible text is transcribed.
''';

  static const _mergePrompt = '''
The following are Markdown text extractions from multiple photos of the same document, taken in order.
Consecutive photos likely overlap — merge them into a single clean Markdown document by:
1. Detecting and removing duplicate/overlapping content between sections
2. Preserving the correct reading order
3. Keeping {option1|option2} uncertainty markers intact
4. Outputting only the final merged Markdown, no commentary
''';

  @override
  Future<String> extractFromImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = imagePath.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: jsonEncode({
        'model': extractModel,
        'max_tokens': 2048,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _extractPrompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mime;base64,$base64Image'},
              },
            ],
          }
        ],
      }),
    );

    final choices = response.data?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return '';
    return (choices.first['message']['content'] as String?) ?? '';
  }

  @override
  Future<String> mergeExtractions(List<String> extractions) async {
    if (extractions.length == 1) return extractions.first;

    final numbered = extractions
        .asMap()
        .entries
        .map((e) => '## Photo ${e.key + 1}\n${e.value}')
        .join('\n\n---\n\n');

    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: jsonEncode({
        'model': mergeModel,
        'max_tokens': 4096,
        'messages': [
          {'role': 'system', 'content': _mergePrompt},
          {'role': 'user', 'content': numbered},
        ],
      }),
    );

    final choices = response.data?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return extractions.join('\n\n');
    return (choices.first['message']['content'] as String?) ?? extractions.join('\n\n');
  }
}
