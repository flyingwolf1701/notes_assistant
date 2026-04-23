import 'dart:convert';
import 'package:dio/dio.dart';

class OpenAiChatService {
  OpenAiChatService({
    required String baseUrl,
    required String apiKey,
    required this.model,
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $apiKey'},
        ));

  final Dio _dio;
  final String model;

  Future<String> refine(String rawText, {required String systemPrompt}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: jsonEncode({
        'model': model,
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
