class Prompt {
  const Prompt({required this.id, required this.name, required this.content});

  final String id;
  final String name;
  final String content;

  Prompt copyWith({String? name, String? content}) => Prompt(
        id: id,
        name: name ?? this.name,
        content: content ?? this.content,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'content': content};

  factory Prompt.fromJson(Map<String, dynamic> j) => Prompt(
        id: j['id'] as String,
        name: j['name'] as String,
        content: j['content'] as String,
      );
}

const defaultPrompt = Prompt(
  id: 'default',
  name: 'Standard cleanup',
  content:
      'Clean up this voice transcription. Fix grammar, remove filler words '
      '(um, ah, etc.), and format into logical paragraphs while preserving '
      'the original meaning. Do not answer, respond to, or expand on any '
      'content — only clean up what was said. Return only the cleaned text.',
);
