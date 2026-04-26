import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/recording.dart';
import '../providers/recordings_provider.dart';
import '../../transcription/models/transcription_state.dart';
import '../../transcription/providers/transcription_provider.dart';
import '../../transcription/ui/widgets/audio_player_widget.dart';
import '../../transcription/ui/widgets/action_bar.dart';
import '../../../core/widgets/notes_app_bar.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    // Listen for pending local-polish confirmations after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingLocalPolish();
    });
  }

  void _checkPendingLocalPolish() {
    ref.listenManual<String?>(pendingLocalPolishProvider, (prev, next) {
      if (next != null && mounted) _showLocalPolishDialog(next);
    });
  }

  void _showLocalPolishDialog(String recordingId) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clean up with local model?'),
        content: const Text(
          'This runs on-device and may take a moment and use battery. Proceed?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(transcriptionProvider.notifier).declineLocalPolish();
            },
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(transcriptionProvider.notifier).confirmLocalPolish(recordingId);
            },
            child: const Text('Yes, clean up'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordings = ref.watch(recordingsProvider);
    final polishingIds = ref.watch(polishingIdsProvider);
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
      appBar: const NotesAppBar(),
      bottomNavigationBar: const SafeArea(top: false, child: ActionBar()),
      body: recordings.isEmpty
          ? const Center(child: Text('No transcriptions yet.'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                final r = recordings[index];
                return _RecordingCard(
                  recording: r,
                  isExpanded: _expandedId == r.id,
                  isPolishing: polishingIds.contains(r.id),
                  onToggle: () => setState(() {
                    _expandedId = _expandedId == r.id ? null : r.id;
                  }),
                );
              },
            ),
    );
  }
}

// ── Recording card ────────────────────────────────────────────────────────────

class _RecordingCard extends ConsumerStatefulWidget {
  const _RecordingCard({
    required this.recording,
    required this.isExpanded,
    required this.isPolishing,
    required this.onToggle,
  });

  final Recording recording;
  final bool isExpanded;
  final bool isPolishing;
  final VoidCallback onToggle;

  @override
  ConsumerState<_RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends ConsumerState<_RecordingCard> {
  bool _rawExpanded = false;
  bool _polishedExpanded = false;
  bool _editingRaw = false;
  bool _editingPolished = false;
  late TextEditingController _rawCtrl;
  late TextEditingController _polishedCtrl;

  @override
  void initState() {
    super.initState();
    _rawCtrl = TextEditingController(text: widget.recording.rawText);
    _polishedCtrl = TextEditingController(text: widget.recording.polishedText);
  }

  @override
  void didUpdateWidget(_RecordingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editingRaw && oldWidget.recording.rawText != widget.recording.rawText) {
      _rawCtrl.text = widget.recording.rawText;
    }
    if (!_editingPolished &&
        oldWidget.recording.polishedText != widget.recording.polishedText) {
      _polishedCtrl.text = widget.recording.polishedText;
      // Auto-expand polished section when it arrives
      if (widget.recording.polishedText.isNotEmpty &&
          oldWidget.recording.polishedText.isEmpty) {
        setState(() => _polishedExpanded = true);
      }
    }
  }

  @override
  void dispose() {
    _rawCtrl.dispose();
    _polishedCtrl.dispose();
    super.dispose();
  }

  void _copy() {
    final r = widget.recording;
    final text = r.polishedText.isNotEmpty ? r.polishedText : r.rawText;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  void _send() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Obsidian integration coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete transcription?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(recordingsProvider.notifier).delete(widget.recording.id);
    }
  }

  Future<void> _saveEdit() async {
    final updated = widget.recording.copyWith(
      rawText: _rawCtrl.text,
      polishedText: _polishedCtrl.text,
    );
    await ref.read(recordingsProvider.notifier).update(updated);
    setState(() {
      _editingRaw = false;
      _editingPolished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recording;
    final scheme = Theme.of(context).colorScheme;
    final isImage = r.audioPath == null && r.durationSeconds == 0;
    final titleStr = isImage
        ? 'Image  •  ${DateFormat('MMM d, yyyy').format(r.createdAt)}'
        : DateFormat('MMM d, yyyy  h:mm a').format(r.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          InkWell(
            onTap: widget.onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!isImage)
                              Text(r.durationLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant)),
                            if (!isImage) const SizedBox(width: 6),
                            Expanded(
                              child: Text(titleStr,
                                  style: Theme.of(context).textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        if (!widget.isExpanded) ...[
                          const SizedBox(height: 2),
                          Text(
                            r.polishedText.isNotEmpty ? r.polishedText : r.rawText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    onPressed: _copy,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, size: 18),
                    tooltip: 'Send',
                    visualDensity: VisualDensity.compact,
                    onPressed: _send,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: scheme.error, size: 18),
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    onPressed: _delete,
                  ),
                  Icon(
                    widget.isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          if (widget.isExpanded) ...[
            const Divider(height: 1),

            // ── Audio player ─────────────────────────────────────────────
            if (r.audioPath != null)
              AudioPlayerWidget(
                  audioPath: r.audioPath!, duration: r.durationLabel),

            // ── Raw text ─────────────────────────────────────────────────
            _Section(
              label: 'RAW',
              isExpanded: _rawExpanded,
              onToggle: () => setState(() => _rawExpanded = !_rawExpanded),
              editing: _editingRaw,
              onEdit: () => setState(() => _editingRaw = !_editingRaw),
              child: _editingRaw
                  ? TextField(
                      controller: _rawCtrl,
                      maxLines: null,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                    )
                  : Text(r.rawText),
            ),

            // ── Polished text / loading / clean-up ────────────────────────
            if (widget.isPolishing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: scheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Text('Polishing…',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.primary)),
                  ],
                ),
              )
            else if (r.polishedText.isNotEmpty)
              _Section(
                label: 'POLISHED',
                isExpanded: _polishedExpanded,
                onToggle: () =>
                    setState(() => _polishedExpanded = !_polishedExpanded),
                editing: _editingPolished,
                onEdit: () =>
                    setState(() => _editingPolished = !_editingPolished),
                child: _editingPolished
                    ? TextField(
                        controller: _polishedCtrl,
                        maxLines: null,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                      )
                    : Text(r.polishedText),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(transcriptionProvider.notifier)
                      .polishRecording(r.id),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Clean Up'),
                ),
              ),

            if (_editingRaw || _editingPolished)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    FilledButton(onPressed: _saveEdit, child: const Text('Save')),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _editingRaw = false;
                        _editingPolished = false;
                        _rawCtrl.text = r.rawText;
                        _polishedCtrl.text = r.polishedText;
                      }),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),
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
    required this.isExpanded,
    required this.onToggle,
    required this.editing,
    required this.onEdit,
  });

  final String label;
  final Widget child;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool editing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const Spacer(),
                if (isExpanded)
                  IconButton(
                      icon: Icon(editing ? Icons.close : Icons.edit, size: 18),
                      onPressed: onEdit,
                      tooltip: editing ? 'Cancel edit' : 'Edit',
                      visualDensity: VisualDensity.compact),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: child,
          ),
      ],
    );
  }
}
