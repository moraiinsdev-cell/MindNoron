import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import 'catalyst_idea.dart';

/// Persists AI Idea Catalyst output in the Drift key/value settings table, so
/// briefs run during a hackathon survive restarts. Mirrors the Office idea
/// persistence pattern (newest-first, capped) but stays entirely separate — the
/// Office board remains offline and untouched.
class CatalystRepository {
  CatalystRepository(this._settings);

  final SettingsRepository _settings;

  static const _kIdeas = 'catalystIdeasV1';

  /// Keep at most this many ideas on disk (newest kept).
  static const _cap = 100;

  Stream<List<CatalystIdea>> watchIdeas() =>
      _settings.watchValue(_kIdeas).map(CatalystIdea.decodeList);

  Future<List<CatalystIdea>> getIdeas() async =>
      CatalystIdea.decodeList(await _settings.readValue(_kIdeas));

  Future<void> _save(List<CatalystIdea> ideas) {
    final capped = ideas.length > _cap ? ideas.sublist(0, _cap) : ideas;
    return _settings.setValue(_kIdeas, CatalystIdea.encodeList(capped));
  }

  /// Prepends freshly generated ideas (newest first) and trims to the cap.
  Future<void> addIdeas(List<CatalystIdea> fresh) async {
    if (fresh.isEmpty) return;
    final existing = await getIdeas();
    await _save([...fresh, ...existing]);
  }

  Future<void> setStarred(String id, bool starred) => _mutate(
        id,
        (i) => i.copyWith(starred: starred),
      );

  Future<void> dismiss(String id) async {
    final ideas = await getIdeas();
    await _save(ideas.where((i) => i.id != id).toList());
  }

  Future<void> _mutate(
      String id, CatalystIdea Function(CatalystIdea) change) async {
    final ideas = await getIdeas();
    await _save([
      for (final i in ideas)
        if (i.id == id) change(i) else i
    ]);
  }
}

final catalystRepositoryProvider = Provider<CatalystRepository>((ref) {
  return CatalystRepository(ref.watch(settingsRepositoryProvider));
});

/// Catalyst ideas the player has generated, newest first.
final catalystIdeasProvider = StreamProvider<List<CatalystIdea>>((ref) {
  return ref.watch(catalystRepositoryProvider).watchIdeas();
});
