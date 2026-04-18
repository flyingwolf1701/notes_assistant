import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transcription_state.dart';
import '../providers/transcription_provider.dart';
import 'widgets/action_bar.dart';
import 'widgets/checkbox_header.dart';
import 'widgets/transcription_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transcriptionProvider);
    final scheme = Theme.of(context).colorScheme;

    // Show error snackbar whenever errorMessage is set
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
        title: const Text('Notes Assistant'),
        centerTitle: true,
        actions: [
          // Recording status indicator
          if (state.isRecording)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: scheme.error, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'REC',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),

      body: Column(
        children: [
          // ── Checkbox header ──────────────────────────────────────────────
          const CheckboxHeader(),

          // ── Transcription cards ──────────────────────────────────────────
          Expanded(
            child: state.isProcessing
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: scheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Transcribing & polishing…',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    children: const [
                      TranscriptionCard(
                        cardEditMode: EditMode.raw,
                        title: 'RAW TRANSCRIPTION',
                      ),
                      TranscriptionCard(
                        cardEditMode: EditMode.polished,
                        title: 'POLISHED TRANSCRIPTION',
                      ),
                    ],
                  ),
          ),

          // ── Action bar ───────────────────────────────────────────────────
          const ActionBar(),
        ],
      ),
    );
  }
}
