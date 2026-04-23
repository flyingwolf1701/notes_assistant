import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'features/transcription/providers/transcription_provider.dart';

const _kDevKeys = {
  'api_key_groq': String.fromEnvironment('GROQ_API_KEY'),
  'api_key_openrouter': String.fromEnvironment('OPENROUTER_API_KEY'),
  'api_key_siliconflow': String.fromEnvironment('SILICONFLOW_API_KEY'),
};

Future<void> _seedDevKeys(SharedPreferences prefs) async {
  for (final entry in _kDevKeys.entries) {
    if (entry.value.isNotEmpty) {
      await prefs.setString(entry.key, entry.value);
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(900, 700),
      minimumSize: Size(640, 480),
      center: true,
      title: 'Notes Assistant',
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final prefs = await SharedPreferences.getInstance();
  await _seedDevKeys(prefs);
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NotesAssistantApp(),
    ),
  );
}
