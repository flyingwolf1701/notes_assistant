import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../services/processing_repository.dart';

/// OpenRouter implementation of [ProcessingRepository].
/// Uses Whisper for transcription and the cheapest available model for refinement.
class OpenRouterRepository implements ProcessingRepository {
  OpenRouterRepository({required String apiKey})
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://openrouter.ai/api/v1',
            headers: {
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'com.example.notes_assistant',
              'X-Title': 'Notes Assistant',
            },
          ),
        );

  final Dio _dio;

  // ── Transcription ────────────────────────────────────────────────────────────

  @override
  Future<String> transcribe(String audioPath) async {
    final file = File(audioPath);
    final formData = FormData.fromMap({
      'model': 'openai/whisper-1',
      'file': await MultipartFile.fromFile(
        file.path,
        filename: 'audio.m4a',
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/audio/transcriptions',
      data: formData,
    );

    return (response.data?['text'] as String?) ?? '';
  }

  // ── Refinement ───────────────────────────────────────────────────────────────

  @override
  Future<String> refine(String rawText) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: jsonEncode({
        // Let OpenRouter pick the cheapest available model
        'model': 'openrouter/auto',
        'messages': [
          {
            'role': 'system',
            'content':
                'Clean up the following voice transcription. Fix grammar, '
                'remove filler words like "um" and "ah", and format it into '
                'logical paragraphs while maintaining the original meaning.',
          },
          {
            'role': 'user',
            'content': rawText,
          },
        ],
      }),
    );

    final choices = response.data?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return rawText;
    return (choices.first['message']['content'] as String?) ?? rawText;
  }
}
