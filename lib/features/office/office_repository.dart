import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import 'office_default_layout.dart';
import 'office_economy.dart';
import 'office_idea_engine.dart';
import 'office_models.dart';

/// Persists the MindNoron Inc. roster in the settings key/value table —
/// names, looks, roles and pinned tasks survive restarts; positions and
/// moods are recomputed by the simulation.
///
/// Also persists the player's [OfficeEconomy] (coins, unlocks) and the
/// build-mode furniture layout ([PlacedItem]s).
class OfficeRepository {
  OfficeRepository(this._settings);

  final SettingsRepository _settings;

  /// Bumping a key reseeds saved data with the latest defaults.
  /// v4: the roster spread across five floors (~30 staff).
  static const _kStaff = 'officeStaffV4';
  static const _kEconomy = 'officeEconomyV1';
  /// v2: ships a fully furnished "MAX level" campus by default.
  static const _kLayout = 'officeLayoutV2';
  static const _kSfx = 'officeSfxV1';
  // v2: curated, coherent idea library (v1 produced incoherent slot-filled
  // combinations). Bumping clears the old meaningless ideas.
  static const _kIdeas = 'officeIdeasV2';

  /// Keep at most this many ideas on disk (newest kept).
  static const _ideaCap = 200;

  Stream<List<EmployeeSpec>> watchStaff() =>
      _settings.watchValue(_kStaff).map(_decode);

  Future<List<EmployeeSpec>> getStaff() async =>
      _decode(await _settings.readValue(_kStaff));

  List<EmployeeSpec> _decode(String? raw) {
    final staff = EmployeeSpec.decodeList(raw);
    return staff.isEmpty ? defaultStaff() : staff;
  }

  Future<void> _save(List<EmployeeSpec> staff) =>
      _settings.setValue(_kStaff, EmployeeSpec.encodeList(staff));

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _update(id, (e) => e.copyWith(name: trimmed));
  }

  Future<void> pinTask(String id, String? taskId) =>
      _update(id, (e) => e.copyWith(taskId: () => taskId));

  Future<EmployeeSpec> hire(Random rng, {int floor = 0}) async {
    final staff = await getStaff();
    final hire = rollNewHire(rng, staff, floor: floor);
    await _save([...staff, hire]);
    return hire;
  }

  Future<void> fire(String id) async {
    final staff = await getStaff();
    await _save(staff.where((e) => e.id != id).toList());
  }

  Future<void> _update(
      String id, EmployeeSpec Function(EmployeeSpec) change) async {
    final staff = await getStaff();
    await _save([
      for (final e in staff)
        if (e.id == id) change(e) else e
    ]);
  }

  // --- Economy (coins, unlocks, task-payout ledger) -----------------------

  Stream<OfficeEconomy> watchEconomy() =>
      _settings.watchValue(_kEconomy).map(OfficeEconomy.decode);

  Future<OfficeEconomy> getEconomy() async =>
      OfficeEconomy.decode(await _settings.readValue(_kEconomy));

  Future<void> saveEconomy(OfficeEconomy economy) =>
      _settings.setValue(_kEconomy, economy.encode());

  /// Read-modify-write the economy atomically enough for a single-user app.
  Future<OfficeEconomy> updateEconomy(
      OfficeEconomy Function(OfficeEconomy) change) async {
    final next = change(await getEconomy());
    await saveEconomy(next);
    return next;
  }

  // --- Build-mode furniture layout ----------------------------------------

  Stream<List<PlacedItem>> watchLayout() =>
      _settings.watchValue(_kLayout).map(_decodeLayout);

  Future<List<PlacedItem>> getLayout() async =>
      _decodeLayout(await _settings.readValue(_kLayout));

  /// Falls back to the curated [defaultLayout] (a fully furnished, "MAX level"
  /// campus) until the player saves their own layout in build mode — the same
  /// reseed pattern as [_decode] for the roster.
  List<PlacedItem> _decodeLayout(String? raw) {
    final items = PlacedItem.decodeList(raw);
    return items.isEmpty ? defaultLayout() : items;
  }

  Future<void> saveLayout(List<PlacedItem> items) =>
      _settings.setValue(_kLayout, PlacedItem.encodeList(items));

  // --- Generated ideas (offline idea engine output) -----------------------

  Stream<List<GeneratedIdea>> watchIdeas() =>
      _settings.watchValue(_kIdeas).map(GeneratedIdea.decodeList);

  Future<List<GeneratedIdea>> getIdeas() async =>
      GeneratedIdea.decodeList(await _settings.readValue(_kIdeas));

  Future<void> _saveIdeas(List<GeneratedIdea> ideas) {
    final capped =
        ideas.length > _ideaCap ? ideas.sublist(0, _ideaCap) : ideas;
    return _settings.setValue(_kIdeas, GeneratedIdea.encodeList(capped));
  }

  /// Prepends freshly generated ideas (newest first) and trims to the cap.
  Future<void> addIdeas(List<GeneratedIdea> fresh) async {
    if (fresh.isEmpty) return;
    final existing = await getIdeas();
    await _saveIdeas([...fresh, ...existing]);
  }

  Future<void> setIdeaStarred(String id, bool starred) =>
      _mutateIdea(id, (i) => i.copyWith(starred: starred));

  /// Removes an idea from the board (a soft "not interested").
  Future<void> dismissIdea(String id) async {
    final ideas = await getIdeas();
    await _saveIdeas(ideas.where((i) => i.id != id).toList());
  }

  Future<void> _mutateIdea(
      String id, GeneratedIdea Function(GeneratedIdea) change) async {
    final ideas = await getIdeas();
    await _saveIdeas([
      for (final i in ideas)
        if (i.id == id) change(i) else i
    ]);
  }

  // --- Sound toggle -------------------------------------------------------

  Stream<bool> watchSfxEnabled() =>
      _settings.watchValue(_kSfx).map((v) => v != 'false'); // default on

  Future<void> setSfxEnabled(bool v) => _settings.setValue(_kSfx, '$v');
}

final officeRepositoryProvider = Provider<OfficeRepository>((ref) {
  return OfficeRepository(ref.watch(settingsRepositoryProvider));
});

/// Which building floor the office view is currently showing (0-based).
final currentFloorProvider = StateProvider<int>((ref) => 0);

final officeStaffProvider = StreamProvider<List<EmployeeSpec>>((ref) {
  return ref.watch(officeRepositoryProvider).watchStaff();
});

final officeEconomyProvider = StreamProvider<OfficeEconomy>((ref) {
  return ref.watch(officeRepositoryProvider).watchEconomy();
});

final officeLayoutProvider = StreamProvider<List<PlacedItem>>((ref) {
  return ref.watch(officeRepositoryProvider).watchLayout();
});

final officeSfxEnabledProvider = StreamProvider<bool>((ref) {
  return ref.watch(officeRepositoryProvider).watchSfxEnabled();
});

/// Ideas produced by the office's idea-rooms, newest first.
final officeIdeasProvider = StreamProvider<List<GeneratedIdea>>((ref) {
  return ref.watch(officeRepositoryProvider).watchIdeas();
});
