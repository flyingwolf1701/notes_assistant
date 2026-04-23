import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/local_llm_providers.dart';

class DownloadModelScreen extends ConsumerStatefulWidget {
  const DownloadModelScreen({super.key});

  @override
  ConsumerState<DownloadModelScreen> createState() => _DownloadModelScreenState();
}

class _DownloadModelScreenState extends ConsumerState<DownloadModelScreen> {
  CancelToken? _cancelToken;
  double _progress = 0;
  bool _downloading = false;
  bool _importing = false;
  String? _error;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _importFromGallery() async {
    setState(() { _importing = true; _error = null; });
    final llm = ref.read(localLlmServiceProvider);
    try {
      final hasAccess = await llm.hasAllFilesAccess();
      if (!hasAccess) {
        await llm.requestAllFilesAccess();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grant "All files access" then tap Import from Gallery again'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        setState(() => _importing = false);
        return;
      }
      final destPath = await ref.read(modelDownloaderProvider).modelPath();
      await llm.importGalleryModel(destPath: destPath);
      ref.invalidate(modelDownloadedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model imported from AI Edge Gallery')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
    if (result == null || result.files.single.path == null) return;

    setState(() { _importing = true; _error = null; });
    try {
      final destPath = await ref.read(modelDownloaderProvider).modelPath();
      await File(result.files.single.path!).copy(destPath);
      ref.invalidate(modelDownloadedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model imported successfully')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _error = null; _progress = 0; });
    _cancelToken = CancelToken();
    try {
      await for (final p in ref.read(modelDownloaderProvider).download(cancelToken: _cancelToken)) {
        if (mounted) setState(() => _progress = p.fraction);
      }
      ref.invalidate(modelDownloadedProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _cancel() {
    _cancelToken?.cancel('User cancelled');
    setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = ref.watch(modelDownloadedProvider);
    final busy = _downloading || _importing;

    return Scaffold(
      appBar: AppBar(title: const Text('On-device Model'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gemma 4 E4B', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('gemma-4-E4B-it.litertlm  (~3.65 GB)',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 32),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
            ],
            downloaded.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (isDownloaded) {
                if (isDownloaded) {
                  return Row(children: [
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Model ready'),
                  ]);
                }

                if (_downloading) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                      const SizedBox(height: 8),
                      Text('${(_progress * 100).toStringAsFixed(1)}%'),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
                    ],
                  );
                }

                if (_importing) {
                  return const Row(children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Copying file…'),
                  ]);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.icon(
                      onPressed: busy ? null : _importFromGallery,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Import from AI Edge Gallery'),
                    ),
                    const SizedBox(height: 4),
                    Text('Finds the model you already downloaded in Google AI Edge Gallery',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _importFromFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Import from file'),
                    ),
                    const SizedBox(height: 4),
                    Text('Pick the .litertlm file manually',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _startDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('Download from HuggingFace'),
                    ),
                    const SizedBox(height: 4),
                    Text('~3.65 GB — requires Wi-Fi',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
