import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTrayService with TrayListener {
  DesktopTrayService({
    required this.onToggleRecording,
    required this.onQuit,
  });

  final void Function() onToggleRecording;
  final void Function() onQuit;
  bool _isRecording = false;

  Future<void> init() async {
    if (!_isDesktop) return;
    trayManager.addListener(this);
    await trayManager.setIcon('assets/icon.png');
    await trayManager.setToolTip('Notes Assistant');
    await _rebuildMenu();
  }

  Future<void> setRecording(bool recording) async {
    if (!_isDesktop || _isRecording == recording) return;
    _isRecording = recording;
    await trayManager.setToolTip(
      recording ? 'Notes Assistant — Recording…' : 'Notes Assistant',
    );
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    final menu = Menu(items: [
      MenuItem(key: 'open', label: 'Open Notes Assistant'),
      MenuItem.separator(),
      MenuItem(
        key: 'toggle_record',
        label: _isRecording
            ? 'Stop Recording  (Ctrl+Win+R)'
            : 'Start Recording  (Ctrl+Win+R)',
      ),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        windowManager.show();
        windowManager.focus();
      case 'toggle_record':
        onToggleRecording();
      case 'quit':
        onQuit();
    }
  }

  void dispose() => trayManager.removeListener(this);

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
