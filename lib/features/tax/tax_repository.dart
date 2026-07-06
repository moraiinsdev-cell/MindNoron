import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import 'tax_models.dart';

/// Persists the offline Tax calculator's inputs in the settings key/value table,
/// so a freelancer's numbers survive restarts. Fully offline — no network, in
/// keeping with the app's single-online-feature (Catalyst) rule.
class TaxRepository {
  TaxRepository(this._settings);

  final SettingsRepository _settings;

  Stream<TaxProfile> watchProfile() =>
      _settings.watchTaxProfile().map(TaxProfile.decode);

  Future<TaxProfile> getProfile() async =>
      TaxProfile.decode(await _settings.getTaxProfile());

  Future<void> save(TaxProfile profile) =>
      _settings.setTaxProfile(profile.encode());

  // --- Revenue tracker ----------------------------------------------------

  Stream<List<RevenueEntry>> watchRevenue() =>
      _settings.watchTaxRevenue().map(RevenueEntry.decodeList);

  Future<List<RevenueEntry>> getRevenue() async =>
      RevenueEntry.decodeList(await _settings.getTaxRevenue());

  Future<void> addRevenue(RevenueEntry entry) async {
    final list = await getRevenue();
    await _settings
        .setTaxRevenue(RevenueEntry.encodeList([entry, ...list]));
  }

  Future<void> removeRevenue(String id) async {
    final list = await getRevenue();
    await _settings.setTaxRevenue(
        RevenueEntry.encodeList(list.where((e) => e.id != id).toList()));
  }
}

final taxRepositoryProvider = Provider<TaxRepository>((ref) {
  return TaxRepository(ref.watch(settingsRepositoryProvider));
});

final taxProfileProvider = StreamProvider<TaxProfile>((ref) {
  return ref.watch(taxRepositoryProvider).watchProfile();
});

final taxRevenueProvider = StreamProvider<List<RevenueEntry>>((ref) {
  return ref.watch(taxRepositoryProvider).watchRevenue();
});
