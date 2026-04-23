import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Dart bridge to the LiteRT-LM Kotlin plugin. Android only — other platforms
/// throw [UnsupportedError] if you call anything but [isSupported].
///
/// Single-shot model: one engine + one conversation at a time. Calling
/// [initEngine] a second time tears down the previous engine.
class LocalLlmService {
  LocalLlmService();

  static const _method = MethodChannel('notes_assistant/litertlm');
  static const _events = EventChannel('notes_assistant/litertlm/stream');

  bool get isSupported => Platform.isAndroid;

  Future<bool> isEngineReady() async {
    if (!isSupported) return false;
    final ready = await _method.invokeMethod<bool>('isEngineReady');
    return ready ?? false;
  }

  /// Loads [modelPath] into a LiteRT-LM engine. Can take ~10s; call off the UI.
  /// [backend] is one of `gpu` (default), `cpu`, `npu`.
  Future<void> initEngine({
    required String modelPath,
    String backend = 'gpu',
    String? systemPrompt,
  }) async {
    _ensureSupported();
    await _method.invokeMethod<void>('initEngine', {
      'modelPath': modelPath,
      'backend': backend,
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
    });
  }

  /// Streams token chunks as they arrive. The stream completes normally on
  /// model `done`, or with an error on native failure. Cancelling the
  /// subscription does NOT cancel the native inference — call [cancelStream].
  Stream<String> sendMessage({
    required String text,
    String? imagePath,
    String? audioPath,
  }) {
    _ensureSupported();
    final controller = StreamController<String>();
    late StreamSubscription sub;
    sub = _events.receiveBroadcastStream().listen(
      (event) {
        final map = Map<String, dynamic>.from(event as Map);
        switch (map['type']) {
          case 'chunk':
            controller.add((map['text'] as String?) ?? '');
          case 'done':
            controller.close();
            sub.cancel();
          case 'error':
            controller.addError(
              Exception((map['message'] as String?) ?? 'native error'),
            );
            controller.close();
            sub.cancel();
        }
      },
      onError: (Object e, StackTrace s) {
        controller.addError(e, s);
        controller.close();
      },
    );

    _method.invokeMethod<void>('sendMessage', {
      'text': text,
      if (imagePath != null) 'imagePath': imagePath,
      if (audioPath != null) 'audioPath': audioPath,
    }).catchError((Object e) {
      controller.addError(e);
      controller.close();
      sub.cancel();
    });

    return controller.stream;
  }

  /// Convenience: collects the full streamed response into a single string.
  Future<String> generate({
    required String text,
    String? imagePath,
    String? audioPath,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in sendMessage(
      text: text,
      imagePath: imagePath,
      audioPath: audioPath,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Future<bool> hasAllFilesAccess() async {
    if (!isSupported) return false;
    final ok = await _method.invokeMethod<bool>('hasAllFilesAccess');
    return ok ?? false;
  }

  Future<void> requestAllFilesAccess() async {
    if (!isSupported) return;
    await _method.invokeMethod<void>('requestAllFilesAccess');
  }

  Future<String?> findGalleryModel() async {
    if (!isSupported) return null;
    return _method.invokeMethod<String>('findGalleryModel');
  }

  /// Copies the model found in AI Edge Gallery to [destPath]. Returns the source path.
  Future<String> importGalleryModel({required String destPath}) async {
    _ensureSupported();
    final src = await _method.invokeMethod<String>('importGalleryModel', {'destPath': destPath});
    return src ?? destPath;
  }

  Future<void> cancelStream() async {
    if (!isSupported) return;
    await _method.invokeMethod<void>('cancelStream');
  }

  Future<void> close() async {
    if (!isSupported) return;
    await _method.invokeMethod<void>('close');
  }

  void _ensureSupported() {
    if (!isSupported) {
      throw UnsupportedError('LocalLlmService is Android-only');
    }
  }
}
