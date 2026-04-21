class Recording {
  const Recording({
    required this.id,
    required this.createdAt,
    required this.durationSeconds,
    required this.rawText,
    this.audioPath,
    this.polishedText = '',
  });

  final String id;
  final DateTime createdAt;
  final int durationSeconds;
  final String? audioPath;
  final String rawText;
  final String polishedText;

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Recording copyWith({String? rawText, String? polishedText}) {
    return Recording(
      id: id,
      createdAt: createdAt,
      durationSeconds: durationSeconds,
      audioPath: audioPath,
      rawText: rawText ?? this.rawText,
      polishedText: polishedText ?? this.polishedText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'audioPath': audioPath,
        'rawText': rawText,
        'polishedText': polishedText,
      };

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        durationSeconds: j['durationSeconds'] as int,
        audioPath: j['audioPath'] as String?,
        rawText: j['rawText'] as String? ?? '',
        polishedText: j['polishedText'] as String? ?? '',
      );
}
