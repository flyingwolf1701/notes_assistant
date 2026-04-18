import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transcription_provider.dart';

/// Top row of three checkboxes: Raw | Polished | Audio
/// Controls what gets exported to clipboard / Obsidian.
class CheckboxHeader extends ConsumerWidget {
  const CheckboxHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transcriptionProvider);
    final notifier = ref.read(transcriptionProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CheckItem(
            label: 'Raw',
            value: state.exportRaw,
            onChanged: notifier.setExportRaw,
          ),
          _CheckItem(
            label: 'Polished',
            value: state.exportPolished,
            onChanged: notifier.setExportPolished,
          ),
          _CheckItem(
            label: 'Audio',
            value: state.exportAudio,
            onChanged: notifier.setExportAudio,
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
