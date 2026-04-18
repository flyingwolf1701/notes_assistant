# Technical Specification: AI Voice-to-Obsidian (Flutter)

This document outlines the architecture for a Flutter-based Android application that records voice,
processes it through transcription and LLM refinement (local or cloud), and exports the result to Obsidian.

---

## 1. App Vision & Roadmap

### Phase 1: MVP (Current Focus)

- **Recording:** High-quality voice capture.
- **Processing:** Audio compression using Opus.
- **Transcription:** Cloud-based via OpenRouter (Whisper).
- **Refinement:** Cloud-based via OpenRouter (least expensive option).
- **Output:** Toggle-based selection (Raw and/or Polished) to be copied to the clipboard. (Audio isn't copied to clipboard)

### Phase 2: Local Intelligence

- **Local Transcription:** Integration of `whisper.cpp` via FFI using packages like `whisper_flutter_new` or `whisper_kit`.
- **Local Refinement:** Integration of Google MediaPipe (Gemma 2/4) via `flutter_gemma`.
- **Settings:** Toggle between Local and Cloud providers.

### Phase 3: Obsidian Integration

- **Obsidian Button:** Activate the primary action button to trigger the Obsidian save flow.
- **Storage Access:** Implement Storage Access Framework (SAF) to link to a specific Obsidian Vault folder.
- **File Creation:** Automatically generate and save a `.md` file containing the selected options
  (Raw, Polished, and/or Audio link) and save the `.opus` file to the vault's attachment folder.

### Phase 4: Vision & Beyond

- **Image-to-Text:** Transcription (OCR + LLM) for handwritten notes using the "Transcribe from image" button.
- **Advanced Organization:** Automated tagging and folder routing within Obsidian based on transcript content.

---

## 2. UI Architecture (Based on Sketch)

The UI will be built using Modern Declarative UI patterns in Flutter.

- **Header:** `CheckboxListTile` row for selection: `[ ] Raw`, `[ ] Polished`, `[ ] Audio`.
- **Content:**
  - **Collapsible Transcription Cards:** Two primary sections (Raw and Polished) using `ExpansionPanel`
    or a custom `AnimatedContainer` logic.
    - **Read Mode:** Multiple cards (0, 1, or both) can be expanded simultaneously in a read-only state
      to allow for side-by-side comparison of the raw and polished results.
    - **Edit Mode:** An "Edit" (pencil icon) button in the card header toggles the view to a `TextField`
      for manual corrections.
    - **Exclusive Write Lock:** Only one card can be in "Edit Mode" at a time. Entering edit mode on one
      card automatically switches any other card back to "Read Mode" to prevent synchronization conflicts.
- **Footer (Action Bar):**
  1. Mic Icon: Start/Stop Recording.
  2. Obsidian/Send Icon: Trigger the pipeline (Process → Transcribe → Refine → Save to Obsidian).
  3. Image Icon: Placeholder for Image-to-Text (Phase 4).
  4. Copy Icon: Copy selected content to clipboard.

---

## 3. Technology Stack

| Component            | Recommended Flutter Package                              |
|----------------------|----------------------------------------------------------|
| State Management     | `flutter_riverpod`                                       |
| Audio Recording      | `record`                                                 |
| Compression          | `opus_dart` or `flutter_opus`                            |
| Networking           | `dio` + `retrofit`                                       |
| Local Transcription  | `whisper_flutter_new`                                    |
| Local Refinement     | `flutter_gemma`                                          |
| Local Storage        | `shared_preferences` + `path_provider`                   |
| Obsidian Access      | `shared_storage` (Android SAF/Scoped Storage)            |

---

## 4. Core Pipeline Logic

```dart
// Conceptual Pipeline Flow
Future<void> processRecording() async {
  // 1. Capture & Compress
  final rawPath = await recorder.stop();
  final compressedPath = await opusEncoder.encode(rawPath);

  // 2. Transcribe (Toggleable)
  final rawText = settings.useLocal
      ? await localWhisper.transcribe(compressedPath) // Uses whisper_flutter_new
      : await openRouter.transcribe(compressedPath);

  // 3. Refine (Toggleable)
  final polishedText = settings.useLocal
      ? await localGemma.refine(rawText) // Uses flutter_gemma
      : await openRouter.refine(rawText);

  // 4. Update UI State
  state = state.copyWith(raw: rawText, polished: polishedText);
}
```

---

## 5. AI Coding Assistant Prompt

> Act as a Senior Flutter Architect. Scaffold a Flutter app using Riverpod state management for a
> voice processing pipeline.
>
> **UI Requirements:**
> 1. Follow a layout with three checkboxes at the top (Raw, Polished, Audio).
> 2. Create two collapsible cards for 'Raw Transcription' and 'Polished Transcription'.
> 3. Implement logic where both cards can be open for reading simultaneously, but only one card
>    can be in 'Edit Mode' at a time.
> 4. 'Edit Mode' should toggle between a display `Text` widget and an editable `TextField`.
> 5. A bottom navigation bar with four icons: Record (Mic), Process/Send (Folder/Cloud),
>    Image (Camera), and Copy (Clipboard).
>
> **Logic Requirements:**
> 1. Create a `RecordingService` using the `record` package.
> 2. Implement a `ProcessingRepository` that defines an interface for Transcription and Refinement.
> 3. Provide an `OpenRouterImplementation` of the repository using `Dio` to send audio/text to
>    OpenRouter's `/chat/completions` endpoint.
> 4. Create a logic handler where the 'Copy' button checks the state of the top three checkboxes
>    and concatenates the relevant strings (Raw, Polished, and a placeholder link for Audio) into the clipboard.
>
> **Code Style:** Clean Architecture, separate UI from Business Logic, use `Material 3` design tokens.

---

## 6. Implementation Notes

### Collapsible & Editable UI
Use a `TextEditingController` for each transcription area. To manage the "one card editing" rule,
maintain an enum in your Riverpod state:
```dart
enum EditMode { none, raw, polished }
```

### Local Transcription Options
- **`whisper_flutter_new`:** Direct wrapper for `whisper.cpp`. Supports standard models (tiny, base, small),
  runs entirely on CPU. Significantly more accurate than native Android STT.
- **`whisper_kit`:** Another solid option for Android that handles model downloading and caching.

### Opus vs FFmpeg
FFmpeg adds ~20-50MB to app size. Using `opus_dart` (wraps `libopus` via FFI) keeps the app lightweight
and is specifically optimized for voice.

### Clipboard Logic
```dart
String output = "";
if (rawChecked) output += "# Raw\n${rawController.text}\n\n";
if (polishedChecked) output += "# Polished\n${polishedController.text}\n\n";
// Audio link placeholder for later Obsidian integration
if (audioChecked) output += "![[audio_link.opus]]";
Clipboard.setData(ClipboardData(text: output));
```

### OpenRouter Polishing Prompt
```
System: "Clean up the following voice transcription. Fix grammar, remove filler words like 'um' and 'ah',
and format it into logical paragraphs while maintaining the original meaning."
```

---

## 7. UI Sketch Reference

`ui_sketch.jpg` — Hand-drawn wireframe showing:
- Top row: three checkboxes (Raw checked, Polished unchecked, Audio unchecked)
- RAW TRANSCRIPTION collapsible card (body text lines)
- POLISHED Transcription collapsible card (body text lines)
- Editor toggle section (A B C D format icons)
- Bottom action bar: Transcribe from audio | Send to Obsidian | Transcribe from image | Copy
