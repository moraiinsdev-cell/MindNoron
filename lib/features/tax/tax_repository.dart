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
}

final taxRepositoryProvider = Provider<TaxRepository>((ref) {
  return TaxRepository(ref.watch(settingsRepositoryProvider));
});

final taxProfileProvider = StreamProvider<TaxProfile>((ref) {
  return ref.watch(taxRepositoryProvider).watchProfile();
});
