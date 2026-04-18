import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Wraps the `record` package for audio capture.
/// Outputs an .opus file in the app's temp directory.
class RecordingService {
  RecordingService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentPath;

  /// Starts recording. Returns the output file path.
  Future<String> start() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentPath = '${dir.path}/recording_$timestamp.opus';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.opus,
        sampleRate: 16000, // Whisper optimal sample rate
        numChannels: 1,    // Mono for speech
        bitRate: 32000,    // 32kbps — good quality / small size
      ),
      path: _currentPath!,
    );

    return _currentPath!;
  }

  /// Stops recording and returns the saved file path.
  Future<String?> stop() async {
    final path = await _recorder.stop();
    return path;
  }

  /// True while actively capturing audio.
  Future<bool> get isRecording => _recorder.isRecording();

  /// Clean up the recorder resources.
  Future<void> dispose() => _recorder.dispose();

  /// Delete a temporary recording file after it has been processed.
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
