import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../image_transcription/ui/image_transcription_screen.dart';
import '../../providers/transcription_provider.dart';

class ActionBar extends ConsumerWidget {
  const ActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transcriptionProvider);
    final notifier = ref.read(transcriptionProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final canPop = Navigator.canPop(context);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Home — return to transcriptions list
          _ActionButton(
            icon: Icons.home,
            label: 'Home',
            color: scheme.primary,
            onTap: canPop
                ? () => Navigator.popUntil(context, (r) => r.isFirst)
                : null,
          ),

          // 2. Mic — Record / Stop (navigates to recording screen if at root)
          _ActionButton(
            icon: state.isRecording ? Icons.stop_circle : Icons.mic,
            label: state.isRecording ? 'Stop' : 'Record',
            color: state.isRecording ? scheme.error : scheme.primary,
            isLoading: state.isProcessing,
            onTap: state.isProcessing
                ? null
                : () => notifier.toggleRecording(),
          ),

          // 2. Transcribe from image
          _ActionButton(
            icon: Icons.image_search,
            label: 'Image',
            color: scheme.tertiary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ImageTranscriptionScreen()),
            ),
          ),

        ],
      ),
    );
  }

}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: color,
                    ),
                  )
                : Icon(
                    icon,
                    size: 28,
                    color: onTap == null
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                        : color,
                  ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: onTap == null
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                        : color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
