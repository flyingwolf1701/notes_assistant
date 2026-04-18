import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/transcription_state.dart';
import '../../providers/transcription_provider.dart';

/// A collapsible card for either the Raw or Polished transcription.
///
/// Behaviour:
/// - Multiple cards can be expanded simultaneously (read mode).
/// - Only one card can be in Edit Mode at a time (exclusive write lock).
/// - Edit mode swaps the static [Text] for a [TextField].
class TranscriptionCard extends ConsumerStatefulWidget {
  const TranscriptionCard({
    super.key,
    required this.cardEditMode,  // EditMode.raw or EditMode.polished
    required this.title,
  });

  final EditMode cardEditMode;
  final String title;

  @override
  ConsumerState<TranscriptionCard> createState() => _TranscriptionCardState();
}

class _TranscriptionCardState extends ConsumerState<TranscriptionCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = ref.read(transcriptionProvider);
    _controller = TextEditingController(
      text: widget.cardEditMode == EditMode.raw
          ? state.rawText
          : state.polishedText,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isThisCard(EditMode mode) => widget.cardEditMode == mode;

  bool _isExpanded(TranscriptionState state) =>
      widget.cardEditMode == EditMode.raw
          ? state.isRawExpanded
          : state.isPolishedExpanded;

  String _getText(TranscriptionState state) =>
      widget.cardEditMode == EditMode.raw ? state.rawText : state.polishedText;

  void _toggleExpanded(TranscriptionNotifier notifier) {
    widget.cardEditMode == EditMode.raw
        ? notifier.toggleRawExpanded()
        : notifier.togglePolishedExpanded();
  }

  void _saveEdit(TranscriptionNotifier notifier) {
    widget.cardEditMode == EditMode.raw
        ? notifier.updateRawText(_controller.text)
        : notifier.updatePolishedText(_controller.text);
    notifier.setEditMode(EditMode.none);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptionProvider);
    final notifier = ref.read(transcriptionProvider.notifier);

    final isExpanded = _isExpanded(state);
    final isEditing = _isThisCard(state.editMode);
    final text = _getText(state);

    // Keep controller in sync when text changes from outside (e.g. new recording)
    if (!isEditing && _controller.text != text) {
      _controller.text = text;
    }

    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: Column(
        children: [
          // ── Card Header ──────────────────────────────────────────────────
          InkWell(
            onTap: () => _toggleExpanded(notifier),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                  // Edit / Done button
                  if (text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        isEditing ? Icons.check_circle_outline : Icons.edit,
                        color: isEditing
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      tooltip: isEditing ? 'Done editing' : 'Edit',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        if (isEditing) {
                          _saveEdit(notifier);
                        } else {
                          // Exclusive write lock: exit any other edit mode first
                          notifier.setEditMode(widget.cardEditMode);
                        }
                      },
                    ),
                  // Expand / collapse chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),

          // ── Card Body (collapsible) ──────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: isEditing
                  ? TextField(
                      controller: _controller,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Edit transcription…',
                      ),
                    )
                  : text.isEmpty
                      ? Text(
                          'No content yet. Record or transcribe to populate.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        )
                      : SelectableText(
                          text,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
