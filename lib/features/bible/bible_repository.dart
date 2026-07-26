import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import 'bible_verse.dart';

/// Offline persistence for the Holy Bible feature, layered over the Drift
/// key/value settings table (same pattern as the Catalyst and Tax hubs). Stores
/// only tiny facts: favourited verse ids, the preferred language, and a small
/// daily-visit streak. Everything else is derived from [bibleVerses].
class BibleRepository {
  BibleRepository(this._settings);

  final SettingsRepository _settings;

  static const _kFavorites = 'bible.favorites';
  static const _kLang = 'bible.lang'; // 'vi' | 'en'
  static const _kStreak = 'bible.streak';
  static const _kBest = 'bible.bestStreak';
  static const _kLastDay = 'bible.lastDay';

  // ── Favourites ──────────────────────────────────────────────────────────

  Stream<List<String>> watchFavoriteIds() =>
      _settings.watchValue(_kFavorites).map(_decodeIds);

  Future<List<String>> getFavoriteIds() async =>
      _decodeIds(await _settings.readValue(_kFavorites));

  Future<void> toggleFavorite(String id) async {
    if (verseById(id) == null) return;
    final ids = await getFavoriteIds();
    if (ids.remove(id)) {
      await _settings.setValue(_kFavorites, jsonEncode(ids));
    } else {
      await _settings.setValue(_kFavorites, jsonEncode([id, ...ids]));
    }
  }

  static List<String> _decodeIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      // Keep only ids that still resolve to a verse in the current library.
      return decoded
          .whereType<String>()
          .where((id) => verseById(id) != null)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  // ── Language preference (Vietnamese default) ────────────────────────────

  // English is the default; only an explicit 'vi' choice shows Vietnamese.
  Stream<bool> watchEnglish() =>
      _settings.watchValue(_kLang).map((v) => v != 'vi');

  Future<void> setEnglish(bool english) =>
      _settings.setValue(_kLang, english ? 'en' : 'vi');

  // ── Daily-visit streak ──────────────────────────────────────────────────

  Stream<int> watchStreak() =>
      _settings.watchValue(_kStreak).map((v) => int.tryParse(v ?? '') ?? 0);

  /// Records that the Word was opened today and returns the current streak.
  /// Idempotent within a day; increments when opened on consecutive days and
  /// resets to 1 after a gap. Safe to call on every screen entry.
  Future<int> recordVisit([DateTime? now]) async {
    final date = now ?? DateTime.now();
    final today = _dayKey(date);
    final last = await _settings.readValue(_kLastDay);
    var streak = int.tryParse(await _settings.readValue(_kStreak) ?? '') ?? 0;

    if (last == today) return streak == 0 ? 1 : streak;

    final yesterday = _dayKey(date.subtract(const Duration(days: 1)));
    streak = last == yesterday ? streak + 1 : 1;

    await _settings.setValue(_kStreak, '$streak');
    await _settings.setValue(_kLastDay, today);

    final best = int.tryParse(await _settings.readValue(_kBest) ?? '') ?? 0;
    if (streak > best) await _settings.setValue(_kBest, '$streak');
    return streak;
  }

  static String _dayKey(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

final bibleRepositoryProvider = Provider<BibleRepository>((ref) {
  return BibleRepository(ref.watch(settingsRepositoryProvider));
});

/// Favourited verse ids, newest first.
final bibleFavoriteIdsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(bibleRepositoryProvider).watchFavoriteIds();
});

/// Resolved favourite verses, in the order they were saved.
final bibleFavoriteVersesProvider = Provider<List<BibleVerse>>((ref) {
  final ids = ref.watch(bibleFavoriteIdsProvider).valueOrNull ?? const [];
  return [
    for (final id in ids)
      if (verseById(id) case final v?) v,
  ];
});

/// True when the reader prefers the English (KJV) text.
final bibleEnglishProvider = StreamProvider<bool>((ref) {
  return ref.watch(bibleRepositoryProvider).watchEnglish();
});

/// Consecutive days the Word has been opened.
final bibleStreakProvider = StreamProvider<int>((ref) {
  return ref.watch(bibleRepositoryProvider).watchStreak();
});

/// Optional override for the "today" hero when the reader draws another verse
/// ("Another verse"). Holds a verse id; null means show [verseOfDay].
final bibleShuffleProvider = StateProvider<String?>((ref) => null);

/// The verse currently featured on the Today tab: an explicit draw if the
/// reader asked for one this session, otherwise the deterministic daily verse.
final todayVerseProvider = Provider<BibleVerse>((ref) {
  final override = ref.watch(bibleShuffleProvider);
  if (override != null) {
    final v = verseById(override);
    if (v != null) return v;
  }
  return verseOfDay();
});
