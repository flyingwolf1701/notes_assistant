/// Which card is currently in edit mode.
enum EditMode { none, raw, polished }

/// Recording lifecycle state.
enum RecordingStatus { idle, recording, processing }

/// The top-level immutable state managed by Riverpod.
class TranscriptionState {
  const TranscriptionState({
    this.rawText = '',
    this.polishedText = '',
    this.audioPath,
    this.editMode = EditMode.none,
    this.recordingStatus = RecordingStatus.idle,
    this.recordingSeconds = 0,
    this.isRawExpanded = true,
    this.isPolishedExpanded = true,
    this.exportRaw = true,
    this.exportPolished = false,
    this.exportAudio = false,
    this.errorMessage,
  });

  final String rawText;
  final String polishedText;
  final String? audioPath;
  final EditMode editMode;
  final RecordingStatus recordingStatus;
  final int recordingSeconds;
  final bool isRawExpanded;
  final bool isPolishedExpanded;
  final bool exportRaw;
  final bool exportPolished;
  final bool exportAudio;
  final String? errorMessage;

  bool get isRecording => recordingStatus == RecordingStatus.recording;
  bool get isProcessing => recordingStatus == RecordingStatus.processing;
  bool get hasContent => rawText.isNotEmpty || polishedText.isNotEmpty;

  String get recordingDuration {
    final m = recordingSeconds ~/ 60;
    final s = recordingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  TranscriptionState copyWith({
    String? rawText,
    String? polishedText,
    String? audioPath,
    EditMode? editMode,
    RecordingStatus? recordingStatus,
    int? recordingSeconds,
    bool? isRawExpanded,
    bool? isPolishedExpanded,
    bool? exportRaw,
    bool? exportPolished,
    bool? exportAudio,
    String? errorMessage,
    bool clearError = false,
    bool clearAudio = false,
  }) {
    return TranscriptionState(
      rawText: rawText ?? this.rawText,
      polishedText: polishedText ?? this.polishedText,
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      editMode: editMode ?? this.editMode,
      recordingStatus: recordingStatus ?? this.recordingStatus,
      recordingSeconds: recordingSeconds ?? this.recordingSeconds,
      isRawExpanded: isRawExpanded ?? this.isRawExpanded,
      isPolishedExpanded: isPolishedExpanded ?? this.isPolishedExpanded,
      exportRaw: exportRaw ?? this.exportRaw,
      exportPolished: exportPolished ?? this.exportPolished,
      exportAudio: exportAudio ?? this.exportAudio,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
