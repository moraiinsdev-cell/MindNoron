import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import 'office_models.dart';

/// Persists the MindNoron Inc. roster in the settings key/value table —
/// names, looks, roles and pinned tasks survive restarts; positions and
/// moods are recomputed by the simulation.
class OfficeRepository {
  OfficeRepository(this._settings);

  final SettingsRepository _settings;
  static const _kStaff = 'officeStaff';

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

  Future<EmployeeSpec> hire(Random rng) async {
    final staff = await getStaff();
    final hire = rollNewHire(rng, staff);
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
}

final officeRepositoryProvider = Provider<OfficeRepository>((ref) {
  return OfficeRepository(ref.watch(settingsRepositoryProvider));
});

final officeStaffProvider = StreamProvider<List<EmployeeSpec>>((ref) {
  return ref.watch(officeRepositoryProvider).watchStaff();
});
