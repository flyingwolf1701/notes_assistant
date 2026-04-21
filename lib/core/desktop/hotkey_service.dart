import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class DesktopHotkeyService {
  static final _recordHotKey = HotKey(
    key: PhysicalKeyboardKey.keyR,
    modifiers: [HotKeyModifier.control, HotKeyModifier.meta],
    scope: HotKeyScope.system,
  );

  static Future<void> register({required void Function() onToggleRecording}) async {
    if (!_isDesktop) return;
    await hotKeyManager.unregisterAll();
    await hotKeyManager.register(
      _recordHotKey,
      keyDownHandler: (_) => onToggleRecording(),
    );
  }

  static Future<void> unregisterAll() async {
    if (!_isDesktop) return;
    await hotKeyManager.unregisterAll();
  }

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
