import 'package:flutter/material.dart';

/// Renders markdown text, turning {option1|option2|option3} tokens into
/// tappable chips. Tapping lets the user pick a candidate or type their own.
class CandidateTextWidget extends StatefulWidget {
  const CandidateTextWidget({
    super.key,
    required this.text,
    required this.onResolved,
  });

  final String text;
  final ValueChanged<String> onResolved;

  @override
  State<CandidateTextWidget> createState() => _CandidateTextWidgetState();
}

class _CandidateTextWidgetState extends State<CandidateTextWidget> {
  late String _current;

  @override
  void initState() {
    super.initState();
    _current = widget.text;
  }

  void _resolveToken(String token, List<String> options) async {
    final ctrl = TextEditingController();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose the correct word',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map((o) => ActionChip(
                        label: Text(o),
                        onPressed: () => Navigator.pop(context, o),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Or type the correct word…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Use this'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen != null && chosen.isNotEmpty) {
      setState(() {
        _current = _current.replaceFirst(token, chosen);
      });
      widget.onResolved(_current);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Split on candidate tokens {a|b|c}
    final regex = RegExp(r'\{([^}]+)\}');
    final spans = <InlineSpan>[];
    int last = 0;

    for (final match in regex.allMatches(_current)) {
      if (match.start > last) {
        spans.add(TextSpan(text: _current.substring(last, match.start)));
      }
      final token = match.group(0)!;
      final options = match.group(1)!.split('|');
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => _resolveToken(token, options),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              options.first,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ));
      last = match.end;
    }

    if (last < _current.length) {
      spans.add(TextSpan(text: _current.substring(last)));
    }

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: spans,
      ),
    );
  }
}
