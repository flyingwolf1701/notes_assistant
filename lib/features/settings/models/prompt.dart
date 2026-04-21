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
      'Clean up the following voice transcription. Fix grammar, '
      'remove filler words like "um" and "ah", and format it into '
      'logical paragraphs while maintaining the original meaning. '
      'Return only the cleaned text, nothing else.',
);
