import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../features/transcription/providers/transcription_provider.dart';
import 'hotkey_service.dart';
import 'tray_service.dart';

class DesktopWrapper extends ConsumerStatefulWidget {
  const DesktopWrapper({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DesktopWrapper> createState() => _DesktopWrapperState();
}

class _DesktopWrapperState extends ConsumerState<DesktopWrapper>
    with WindowListener {
  DesktopTrayService? _tray;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _init();
    }
  }

  Future<void> _init() async {
    await windowManager.setPreventClose(true);
    _tray = DesktopTrayService(
      onToggleRecording: _toggle,
      onQuit: _quit,
    );
    await _tray!.init();
    await DesktopHotkeyService.register(onToggleRecording: _toggle);
  }

  void _toggle() =>
      ref.read(transcriptionProvider.notifier).toggleRecording();

  Future<void> _quit() async {
    await DesktopHotkeyService.unregisterAll();
    _tray?.dispose();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
      _tray?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(transcriptionProvider, (prev, next) {
      if (prev?.isRecording != next.isRecording) {
        _tray?.setRecording(next.isRecording);
      }
    });
    return widget.child;
  }

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
