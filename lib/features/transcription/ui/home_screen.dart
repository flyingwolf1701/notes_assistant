import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transcription_state.dart';
import '../providers/transcription_provider.dart';
import '../../../core/widgets/notes_app_bar.dart';
import 'widgets/action_bar.dart';
import 'widgets/audio_player_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transcriptionProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen<TranscriptionState>(transcriptionProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: scheme.error,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: scheme.onError,
              onPressed: () =>
                  ref.read(transcriptionProvider.notifier).clearError(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: NotesAppBar(
        extraActions: [
          if (state.isRecording)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: scheme.error, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'REC  ${state.recordingDuration}',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: const SafeArea(top: false, child: ActionBar()),
      body: state.isProcessing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 16),
                  Text('Transcribing & polishing…',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          : state.hasContent
              ? ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: const [_SessionCard()],
                )
              : Center(
                  child: Text(
                    'Record or transcribe an image to get started.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
    );
  }
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends ConsumerStatefulWidget {
  const _SessionCard();

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _expanded = true;
  bool _editingRaw = false;
  bool _editingPolished = false;
  late TextEditingController _rawCtrl;
  late TextEditingController _polishedCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(transcriptionProvider);
    _rawCtrl = TextEditingController(text: s.rawText);
    _polishedCtrl = TextEditingController(text: s.polishedText);
  }

  @override
  void dispose() {
    _rawCtrl.dispose();
    _polishedCtrl.dispose();
    super.dispose();
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  void _saveEdit(TranscriptionState state) {
    final notifier = ref.read(transcriptionProvider.notifier);
    if (_editingRaw) notifier.updateRawText(_rawCtrl.text);
    if (_editingPolished) notifier.updatePolishedText(_polishedCtrl.text);
    setState(() {
      _editingRaw = false;
      _editingPolished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptionProvider);

    if (!_editingRaw && _rawCtrl.text != state.rawText) {
      _rawCtrl.text = state.rawText;
    }
    if (!_editingPolished && _polishedCtrl.text != state.polishedText) {
      _polishedCtrl.text = state.polishedText;
    }

    final previewText =
        state.polishedText.isNotEmpty ? state.polishedText : state.rawText;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          ListTile(
            title: Text('Current Session',
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(
              previewText,
              maxLines: _expanded ? null : 2,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.audioPath != null)
                  Text(state.recordingDuration,
                      style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),

            // ── Audio player ─────────────────────────────────────────────
            if (state.audioPath != null)
              AudioPlayerWidget(
                audioPath: state.audioPath!,
                duration: state.recordingDuration,
              ),

            // ── Raw ───────────────────────────────────────────────────────
            if (state.rawText.isNotEmpty)
              _Section(
                label: 'RAW',
                editing: _editingRaw,
                onCopy: () => _copy(state.rawText),
                onEdit: () =>
                    setState(() => _editingRaw = !_editingRaw),
                child: _editingRaw
                    ? TextField(
                        controller: _rawCtrl,
                        maxLines: null,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder()),
                      )
                    : Text(state.rawText),
              ),

            // ── Polished ──────────────────────────────────────────────────
            if (state.polishedText.isNotEmpty)
              _Section(
                label: 'POLISHED',
                editing: _editingPolished,
                onCopy: () => _copy(state.polishedText),
                onEdit: () =>
                    setState(() => _editingPolished = !_editingPolished),
                child: _editingPolished
                    ? TextField(
                        controller: _polishedCtrl,
                        maxLines: null,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder()),
                      )
                    : Text(state.polishedText),
              ),

            if (_editingRaw || _editingPolished)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    FilledButton(
                        onPressed: () => _saveEdit(state),
                        child: const Text('Save')),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _editingRaw = false;
                        _editingPolished = false;
                        _rawCtrl.text = state.rawText;
                        _polishedCtrl.text = state.polishedText;
                      }),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Section widget ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.child,
    required this.onCopy,
    required this.onEdit,
    required this.editing,
  });

  final String label;
  final Widget child;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: onCopy,
                tooltip: 'Copy',
              ),
              IconButton(
                icon: Icon(editing ? Icons.close : Icons.edit, size: 18),
                onPressed: onEdit,
                tooltip: editing ? 'Cancel edit' : 'Edit',
              ),
            ],
          ),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
