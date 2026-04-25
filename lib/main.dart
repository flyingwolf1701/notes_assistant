import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'features/transcription/providers/transcription_provider.dart';

const _kEnvKeyMap = {
  'GROQ_API_KEY': 'api_key_groq',
  'OPENROUTER_API_KEY': 'api_key_openrouter',
  'SILICONFLOW_API_KEY': 'api_key_siliconflow',
};

Future<void> _seedDevKeys(SharedPreferences prefs) async {
  try {
    final raw = await rootBundle.loadString('.env.json');
    final env = jsonDecode(raw) as Map<String, dynamic>;
    for (final entry in _kEnvKeyMap.entries) {
      final value = env[entry.key] as String?;
      if (value != null && value.isNotEmpty) {
        await prefs.setString(entry.value, value);
      }
    }
  } catch (_) {}
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
