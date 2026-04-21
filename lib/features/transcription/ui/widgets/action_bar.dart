import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../image_transcription/ui/image_transcription_screen.dart';
import '../../providers/transcription_provider.dart';

/// Bottom action bar with four icon buttons:
///   1. Mic  — Start / Stop recording
///   2. Send — Process + (Phase 3) save to Obsidian
///   3. Image — Transcribe from image (Phase 4 placeholder)
///   4. Copy — Copy selected content to clipboard
class ActionBar extends ConsumerWidget {
  const ActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transcriptionProvider);
    final notifier = ref.read(transcriptionProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

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
          // 1. Mic — Record / Stop
          _ActionButton(
            icon: state.isRecording ? Icons.stop_circle : Icons.mic,
            label: state.isRecording ? 'Stop' : 'Record',
            color: state.isRecording ? scheme.error : scheme.primary,
            isLoading: state.isProcessing,
            onTap: state.isProcessing
                ? null
                : () => notifier.toggleRecording(),
          ),

          // 2. Send to Obsidian (Phase 3 — currently disabled)
          _ActionButton(
            icon: Icons.send,
            label: 'Obsidian',
            color: scheme.secondary,
            onTap: () => _showComingSoon(context, 'Obsidian integration'),
          ),

          // 3. Transcribe from image
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

          // 4. Copy to clipboard
          _ActionButton(
            icon: Icons.copy,
            label: 'Copy',
            color: scheme.onSurface,
            onTap: state.hasContent
                ? () async {
                    await notifier.copyToClipboard();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming in a future phase'),
        duration: const Duration(seconds: 2),
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
