import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/transcription/ui/home_screen.dart';

class NotesAssistantApp extends StatelessWidget {
  const NotesAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes Assistant',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
