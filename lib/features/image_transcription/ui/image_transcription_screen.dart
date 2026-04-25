import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/image_transcription_provider.dart';
import '../../recordings/models/recording.dart';
import '../../recordings/providers/recordings_provider.dart';
import '../../../core/widgets/notes_app_bar.dart';
import '../../transcription/ui/widgets/action_bar.dart';

class ImageTranscriptionScreen extends ConsumerWidget {
  const ImageTranscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(imageTranscriptionProvider);
    final notifier = ref.read(imageTranscriptionProvider.notifier);

    return Scaffold(
      appBar: NotesAppBar(
        extraActions: [
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
      bottomNavigationBar: const SafeArea(top: false, child: ActionBar()),
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

class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({required this.state, required this.notifier});
  final ImageSessionState state;
  final ImageTranscriptionNotifier notifier;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  late final TextEditingController _controller;
  bool _isEditing = false;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.mergedMarkdown);
  }

  @override
  void didUpdateWidget(_ResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.mergedMarkdown != widget.state.mergedMarkdown) {
      _controller.text = widget.state.mergedMarkdown;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext context) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final recording = Recording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      durationSeconds: 0,
      rawText: text,
      polishedText: text,
    );
    await ref.read(recordingsProvider.notifier).add(recording);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Saved to transcriptions'),
            duration: Duration(seconds: 2)),
      );
      setState(() => _isEditing = false);
    }
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
        widget.notifier.addImage(result.files.first.path!);
        await widget.notifier.processImages();
      }
    } else {
      final picker = ImagePicker();
      final file =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (file != null) {
        widget.notifier.addImage(file.path);
        await widget.notifier.processImages();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.state.status == ImageSessionStatus.error) {
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
              Text(widget.state.errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: widget.notifier.reset,
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            children: [
              Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                child: Column(
                  children: [
                    // ── Card header ──────────────────────────────────────
                    InkWell(
                      onTap: () =>
                          setState(() => _isExpanded = !_isExpanded),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'IMAGE TRANSCRIPTION',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onSurface,
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_photo_alternate,
                                  color: scheme.onSurfaceVariant),
                              tooltip: 'Add page',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _addMore(context),
                            ),
                            IconButton(
                              icon: Icon(Icons.save_outlined,
                                  color: scheme.onSurfaceVariant),
                              tooltip: 'Save to transcriptions',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _save(context),
                            ),
                            IconButton(
                              icon: Icon(
                                _isEditing
                                    ? Icons.check_circle_outline
                                    : Icons.edit,
                                color: _isEditing
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              tooltip:
                                  _isEditing ? 'Done editing' : 'Edit',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _isEditing = !_isEditing),
                            ),
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child:
                                  const Icon(Icons.keyboard_arrow_down),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── Card body ────────────────────────────────────────
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _isExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _isEditing
                            ? TextField(
                                controller: _controller,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Edit transcription…',
                                ),
                              )
                            : SelectableText(
                                _controller.text,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium,
                              ),
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }
}
