import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/transcription/providers/transcription_provider.dart';

class NotesAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const NotesAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transcriptionProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      title: const Text('Notes Assistant (Flutter)'),
      centerTitle: true,
      actions: [
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
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}
