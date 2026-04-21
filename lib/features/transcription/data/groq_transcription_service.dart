import 'dart:convert';
import 'package:dio/dio.dart';

class GroqTranscriptionService {
  GroqTranscriptionService({required String apiKey})
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.groq.com/openai/v1',
            headers: {'Authorization': 'Bearer $apiKey'},
          ),
        );

  final Dio _dio;

  Future<String> transcribe(String audioPath) async {
    final formData = FormData.fromMap({
      'model': 'whisper-large-v3-turbo',
      'file': await MultipartFile.fromFile(audioPath, filename: 'audio.m4a'),
      'response_format': 'text',
    });

    final response = await _dio.post<dynamic>(
      '/audio/transcriptions',
      data: formData,
    );

    return (response.data as String?) ?? '';
  }

  Future<String> refine(String rawText, {required String systemPrompt}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': rawText},
        ],
      }),
    );

    final choices = response.data?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return rawText;
    return (choices.first['message']['content'] as String?) ?? rawText;
  }
}
