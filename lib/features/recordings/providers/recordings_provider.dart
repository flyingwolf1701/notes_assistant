import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transcription/providers/transcription_provider.dart';
import '../models/recording.dart';
import '../repositories/recordings_repository.dart';

final recordingsRepositoryProvider = Provider<RecordingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecordingsRepository(prefs);
});

class RecordingsNotifier extends Notifier<List<Recording>> {
  @override
  List<Recording> build() {
    final repo = ref.read(recordingsRepositoryProvider);
    repo.purgeExpired();
    return repo.loadAll();
  }

  Future<void> add(Recording recording) async {
    await ref.read(recordingsRepositoryProvider).save(recording);
    state = [recording, ...state];
  }

  Future<void> update(Recording recording) async {
    await ref.read(recordingsRepositoryProvider).update(recording);
    state = [for (final r in state) r.id == recording.id ? recording : r];
  }

  Future<void> delete(String id) async {
    await ref.read(recordingsRepositoryProvider).delete(id);
    state = state.where((r) => r.id != id).toList();
  }
}

final recordingsProvider =
    NotifierProvider<RecordingsNotifier, List<Recording>>(
  RecordingsNotifier.new,
);
