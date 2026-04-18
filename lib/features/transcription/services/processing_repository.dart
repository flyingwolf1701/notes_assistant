/// Abstract interface for transcription + refinement.
/// Swap implementations (OpenRouter vs. local) without changing the rest of the app.
abstract class ProcessingRepository {
  /// Transcribe an audio file at [audioPath] to raw text.
  Future<String> transcribe(String audioPath);

  /// Polish / clean up [rawText] using an LLM.
  Future<String> refine(String rawText);
}
