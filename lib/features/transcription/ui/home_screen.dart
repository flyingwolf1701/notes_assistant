import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transcription_state.dart';
import '../providers/transcription_provider.dart';
import '../../recordings/ui/recordings_screen.dart';
import '../../settings/ui/settings_screen.dart';
import 'widgets/action_bar.dart';
import 'widgets/audio_player_widget.dart';
import 'widgets/checkbox_header.dart';
import 'widgets/transcription_card.dart';

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
      appBar: AppBar(
        title: const Text('Notes Assistant (Flutter)'),
        centerTitle: true,
        actions: [
          if (!state.isRecording) ...[
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Recordings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordingsScreen()),
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
          if (state.isRecording)
            Padding(
              padding: const EdgeInsets.only(right: 16),
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

      body: Column(
        children: [
          const CheckboxHeader(),

          Expanded(
            child: state.isProcessing
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
                : ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    children: [
                      if (state.audioPath != null)
                        AudioPlayerWidget(
                          audioPath: state.audioPath!,
                          duration: state.recordingDuration,
                        ),
                      const TranscriptionCard(
                        cardEditMode: EditMode.raw,
                        title: 'RAW TRANSCRIPTION',
                      ),
                      const TranscriptionCard(
                        cardEditMode: EditMode.polished,
                        title: 'POLISHED TRANSCRIPTION',
                      ),
                    ],
                  ),
          ),

          const SafeArea(top: false, child: ActionBar()),
        ],
      ),
    );
  }
}
