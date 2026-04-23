import 'package:dio/dio.dart';

class GroqTranscriptionService {
  GroqTranscriptionService({
    required String apiKey,
    this.transcribeModel = 'whisper-large-v3-turbo',
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.groq.com/openai/v1',
            headers: {'Authorization': 'Bearer $apiKey'},
          ),
        );

  final Dio _dio;
  final String transcribeModel;

  Future<String> transcribe(String audioPath) async {
    final formData = FormData.fromMap({
      'model': transcribeModel,
      'file': await MultipartFile.fromFile(audioPath, filename: 'audio.m4a'),
      'response_format': 'text',
    });

    final response = await _dio.post<dynamic>(
      '/audio/transcriptions',
      data: formData,
    );

    return (response.data as String?) ?? '';
  }
}
