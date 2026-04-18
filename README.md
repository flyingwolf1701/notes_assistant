# Notes Assistant — AI Voice-to-Obsidian

A Flutter Android app that records your voice, transcribes it via Whisper (OpenRouter),
polishes it with an LLM, and lets you copy or save the result to Obsidian.

---

## Quick Start

### 1. Prerequisites
- Flutter SDK >= 3.3.0
- Android Studio / VS Code with Flutter plugin
- An [OpenRouter](https://openrouter.ai) API key

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Set your API key
The app reads the API key from `SharedPreferences` under the key `openrouter_api_key`.
Add a simple Settings screen (Phase 2) or inject it for testing via the Riverpod override in `main.dart`:

```dart
// In main.dart — quick dev override
runApp(
  ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
    ],
    child: const NotesAssistantApp(),
  ),
);
```

Then save your key once on first launch:
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('openrouter_api_key', 'sk-or-...');
```

### 4. Run
```bash
flutter run
```

---

## Project Structure

```
lib/
├── main.dart                        # Entry point
├── app.dart                         # MaterialApp + theme
├── core/
│   └── theme.dart                   # Material 3 colour tokens
└── features/
    └── transcription/
        ├── models/
        │   └── transcription_state.dart   # Immutable state + EditMode enum
        ├── providers/
        │   └── transcription_provider.dart # Riverpod StateNotifier
        ├── services/
        │   ├── recording_service.dart      # record package wrapper
        │   └── processing_repository.dart  # Abstract interface
        ├── data/
        │   └── open_router_repository.dart # Dio + OpenRouter implementation
        └── ui/
            ├── home_screen.dart            # Main screen
            └── widgets/
                ├── checkbox_header.dart    # Raw / Polished / Audio toggles
                ├── transcription_card.dart # Collapsible + editable card
                └── action_bar.dart        # Mic / Send / Image / Copy
```

---

## Roadmap

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | Record → Whisper → Polish → Clipboard | ✅ MVP scaffolded |
| 2 | Local whisper.cpp + Gemma via flutter_gemma | 🔜 |
| 3 | Obsidian SAF export (.md + .opus) | 🔜 |
| 4 | Image-to-text (OCR + LLM) | 🔜 |

---

## Key Design Decisions

- **Exclusive edit lock** — `EditMode` enum in Riverpod state ensures only one
  transcription card can be in edit mode at a time.
- **Opus encoding** — The `record` package writes directly to `.opus` (Opus codec),
  keeping file sizes small without a heavy FFmpeg dependency.
- **OpenRouter `auto` model** — The refinement call uses `openrouter/auto` so
  OpenRouter selects the cheapest available model automatically.
- **Clean Architecture** — `ProcessingRepository` is an abstract interface; swap
  `OpenRouterRepository` for a local implementation in Phase 2 with zero UI changes.
