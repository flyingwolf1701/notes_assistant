import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/image_transcription_provider.dart';
import 'widgets/candidate_text_widget.dart';

class ImageTranscriptionScreen extends ConsumerWidget {
  const ImageTranscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(imageTranscriptionProvider);
    final notifier = ref.read(imageTranscriptionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image to Text'),
        centerTitle: true,
        actions: [
          if (state.isDone)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Start over',
              onPressed: notifier.reset,
            ),
        ],
      ),
      body: state.isDone || state.status == ImageSessionStatus.error
          ? _ResultView(state: state, notifier: notifier)
          : state.isProcessing
              ? _ProcessingView(state: state)
              : _CaptureView(state: state, notifier: notifier),
      bottomNavigationBar: null,
    );
  }
}

// ── Capture view ─────────────────────────────────────────────────────────────

class _CaptureView extends ConsumerWidget {
  const _CaptureView({required this.state, required this.notifier});
  final ImageSessionState state;
  final ImageTranscriptionNotifier notifier;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static String get _screenshotsPath {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'] ?? '';
      return '$home\\Pictures\\Screenshots';
    }
    return '';
  }

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      dialogTitle: 'Select images to extract text from',
    );
    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) notifier.addImage(file.path!);
      }
    }
  }

  Future<void> _pickFromScreenshots(BuildContext context) async {
    final path = _screenshotsPath;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      dialogTitle: 'Select screenshots',
      initialDirectory: path,
    );
    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) notifier.addImage(file.path!);
      }
    }
  }

  Future<void> _pickMobile(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 90);
    if (file != null) notifier.addImage(file.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (state.imagePaths.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: state.imagePaths.length,
              itemBuilder: (context, i) => Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(state.imagePaths[i]),
                        width: 90,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => notifier.removeImage(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.close, size: 16, color: scheme.onError),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
        ],

        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.document_scanner_outlined,
                    size: 64, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  state.imagePaths.isEmpty
                      ? 'Add images to extract text'
                      : 'Add more images, or tap Extract Text below',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_isDesktop) ...[
                  FilledButton.icon(
                    onPressed: () => _pickFiles(context),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Browse Files'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickFromScreenshots(context),
                    icon: const Icon(Icons.screenshot_monitor),
                    label: const Text('Screenshots Folder'),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            _pickMobile(context, ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _pickMobile(context, ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                    ],
                  ),
                ],
                if (state.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: notifier.processImages,
                    icon: const Icon(Icons.auto_fix_high),
                    label: Text(
                        'Extract Text from ${state.imagePaths.length} image${state.imagePaths.length == 1 ? '' : 's'}'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Processing view ───────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.state});
  final ImageSessionState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(state.progressLabel,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Result view ───────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  const _ResultView({required this.state, required this.notifier});
  final ImageSessionState state;
  final ImageTranscriptionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasCandidates = RegExp(r'\{[^}]+\}').hasMatch(state.mergedMarkdown);

    if (state.status == ImageSessionStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text('Extraction failed',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(state.errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: notifier.reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [

        if (hasCandidates)
          Container(
            color: scheme.tertiaryContainer,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.touch_app,
                    size: 16, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Highlighted words are uncertain — tap to choose the correct one',
                    style: TextStyle(
                        color: scheme.onTertiaryContainer, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CandidateTextWidget(
              text: state.mergedMarkdown,
              onResolved: notifier.resolveCandidates,
            ),
          ),
        ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: state.mergedMarkdown));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Markdown'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _addMore(context),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add page'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addMore(BuildContext context) async {
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (isDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: 'Add another page',
      );
      if (result != null && result.files.first.path != null) {
        notifier.addImage(result.files.first.path!);
        await notifier.processImages();
      }
    } else {
      final picker = ImagePicker();
      final file =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (file != null) {
        notifier.addImage(file.path);
        await notifier.processImages();
      }
    }
  }
}
