import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.received,
    required this.total,
  });

  final int received;
  final int total;

  double get fraction => total <= 0 ? 0 : received / total;
}

/// Downloads the Gemma 4 E4B-it `.litertlm` file from the HuggingFace
/// litert-community repo into app support storage.
///
/// ~3.65 GB, so callers should show progress UI and let the user opt in.
/// Current implementation is NOT resumable — a cancelled download restarts.
class ModelDownloaderService {
  ModelDownloaderService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _repo = 'litert-community/gemma-4-E4B-it-litert-lm';
  static const _fileName = 'gemma-4-E4B-it.litertlm';
  static const _url =
      'https://huggingface.co/$_repo/resolve/main/$_fileName';

  Future<String> modelPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}$_fileName';
  }

  Future<bool> isDownloaded() async {
    return File(await modelPath()).exists();
  }

  /// Emits progress events until download completes. If the file is already
  /// present, emits a single `1.0` fraction and completes.
  Stream<ModelDownloadProgress> download({
    CancelToken? cancelToken,
  }) async* {
    final path = await modelPath();
    final file = File(path);
    if (await file.exists()) {
      final size = await file.length();
      yield ModelDownloadProgress(received: size, total: size);
      return;
    }

    final controller = StreamController<ModelDownloadProgress>();
    // Download to a .part file so an interrupted pull doesn't leave a
    // corrupt .litertlm that looks valid to the engine.
    final partPath = '$path.part';

    unawaited(() async {
      try {
        await _dio.download(
          _url,
          partPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            controller.add(ModelDownloadProgress(
              received: received,
              total: total,
            ));
          },
          options: Options(
            followRedirects: true,
            receiveTimeout: const Duration(minutes: 30),
          ),
        );
        await File(partPath).rename(path);
        await controller.close();
      } catch (e, s) {
        // Leave .part behind; future version can resume.
        controller.addError(e, s);
        await controller.close();
      }
    }());

    yield* controller.stream;
  }
}
