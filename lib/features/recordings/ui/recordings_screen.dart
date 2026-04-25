import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/recording.dart';
import '../providers/recordings_provider.dart';
import '../../transcription/ui/widgets/audio_player_widget.dart';
import '../../transcription/ui/widgets/action_bar.dart';
import '../../../core/widgets/notes_app_bar.dart';

class RecordingsScreen extends ConsumerWidget {
  const RecordingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordings = ref.watch(recordingsProvider);

    return Scaffold(
      appBar: const NotesAppBar(),
      bottomNavigationBar: const SafeArea(top: false, child: ActionBar()),
      body: recordings.isEmpty
          ? const Center(child: Text('No transcriptions yet.'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: recordings.length,
              itemBuilder: (context, index) =>
                  _RecordingCard(recording: recordings[index]),
            ),
    );
  }
}

class _RecordingCard extends ConsumerStatefulWidget {
  const _RecordingCard({required this.recording});
  final Recording recording;

  @override
  ConsumerState<_RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends ConsumerState<_RecordingCard> {
  bool _expanded = false;
  bool _rawExpanded = false;
  bool _polishedExpanded = false;
  bool _rawChecked = true;
  bool _polishedChecked = true;
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
  void dispose() {
    _rawCtrl.dispose();
    _polishedCtrl.dispose();
    super.dispose();
  }

  void _copySelected(Recording r) {
    final buf = StringBuffer();
    if (_rawChecked && r.rawText.isNotEmpty) buf.writeln(r.rawText);
    if (_polishedChecked && r.polishedText.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.write(r.polishedText);
    }
    Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
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
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            title: Text(titleStr,
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(
              r.polishedText.isNotEmpty ? r.polishedText : r.rawText,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isImage)
                  Text(r.durationLabel,
                      style: Theme.of(context).textTheme.labelSmall),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: scheme.error, size: 20),
                  tooltip: 'Delete',
                  onPressed: () async {
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
                      await ref.read(recordingsProvider.notifier).delete(r.id);
                    }
                  },
                ),
              ],
            ),
          ),

          if (_expanded) ...[
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
              checked: _rawChecked,
              onCheck: (v) => setState(() => _rawChecked = v),
              onEdit: () => setState(() => _editingRaw = !_editingRaw),
              editing: _editingRaw,
              child: _editingRaw
                  ? TextField(
                      controller: _rawCtrl,
                      maxLines: null,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    )
                  : Text(r.rawText),
            ),

            // ── Polished text ─────────────────────────────────────────────
            if (r.polishedText.isNotEmpty)
              _Section(
                label: 'POLISHED',
                isExpanded: _polishedExpanded,
                onToggle: () => setState(() => _polishedExpanded = !_polishedExpanded),
                checked: _polishedChecked,
                onCheck: (v) => setState(() => _polishedChecked = v),
                onEdit: () => setState(() => _editingPolished = !_editingPolished),
                editing: _editingPolished,
                child: _editingPolished
                    ? TextField(
                        controller: _polishedCtrl,
                        maxLines: null,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      )
                    : Text(r.polishedText),
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

            // ── Copy / Send ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: (_rawChecked || _polishedChecked)
                        ? () => _copySelected(r)
                        : null,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Obsidian integration coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    ),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send'),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.child,
    required this.isExpanded,
    required this.onToggle,
    required this.checked,
    required this.onCheck,
    required this.onEdit,
    required this.editing,
  });

  final String label;
  final Widget child;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool checked;
  final ValueChanged<bool> onCheck;
  final VoidCallback onEdit;
  final bool editing;

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
                Checkbox(
                  value: checked,
                  onChanged: (v) => onCheck(v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const Spacer(),
                if (isExpanded)
                  IconButton(
                      icon: Icon(editing ? Icons.close : Icons.edit, size: 18),
                      onPressed: onEdit,
                      tooltip: editing ? 'Cancel edit' : 'Edit'),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
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
