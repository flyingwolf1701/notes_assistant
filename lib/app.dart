import 'dart:io';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/desktop/desktop_wrapper.dart';
import 'features/transcription/ui/home_screen.dart';

class NotesAssistantApp extends StatelessWidget {
  const NotesAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Notes Assistant',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return DesktopWrapper(child: app);
    }
    return app;
  }
}
