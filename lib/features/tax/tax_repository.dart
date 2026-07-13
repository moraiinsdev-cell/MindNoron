import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import 'tax_models.dart';
import 'tax_savings.dart';

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

  // --- Savings envelopes --------------------------------------------------

  Stream<List<SavingsFund>> watchFunds() =>
      _settings.watchTaxFunds().map(SavingsFund.decodeList);

  Future<List<SavingsFund>> getFunds() async =>
      SavingsFund.decodeList(await _settings.getTaxFunds());

  Future<void> saveFunds(List<SavingsFund> funds) =>
      _settings.setTaxFunds(SavingsFund.encodeList(funds));

  /// Adds a fund, or replaces the one with the same id.
  Future<void> upsertFund(SavingsFund fund) async {
    final funds = await getFunds();
    final i = funds.indexWhere((f) => f.id == fund.id);
    if (i >= 0) {
      funds[i] = fund;
    } else {
      funds.add(fund);
    }
    await saveFunds(funds);
  }

  /// Drops an envelope *and* its ledger entries — leaving orphaned movements
  /// behind would quietly corrupt every total that is derived from them.
  Future<void> removeFund(String id) async {
    final funds = await getFunds();
    await saveFunds(funds.where((f) => f.id != id).toList());
    final txns = await getFundTxns();
    await _saveTxns(txns.where((t) => t.fundId != id).toList());
  }

  // --- Envelope ledger ----------------------------------------------------

  Stream<List<FundTxn>> watchFundTxns() =>
      _settings.watchTaxFundTxns().map(FundTxn.decodeList);

  Future<List<FundTxn>> getFundTxns() async =>
      FundTxn.decodeList(await _settings.getTaxFundTxns());

  Future<void> _saveTxns(List<FundTxn> txns) =>
      _settings.setTaxFundTxns(FundTxn.encodeList(txns));

  /// Books movements newest-first. Takes a list because splitting one payout
  /// touches several envelopes at once, and a half-written split would leave
  /// the books wrong.
  Future<void> addFundTxns(List<FundTxn> txns) async {
    if (txns.isEmpty) return;
    final list = await getFundTxns();
    await _saveTxns([...txns, ...list]);
  }

  Future<void> removeFundTxn(String id) async {
    final list = await getFundTxns();
    await _saveTxns(list.where((t) => t.id != id).toList());
  }
}

/// Envelope balances, derived from the ledger — the single source of truth for
/// every đồng shown in the Quỹ tab.
Map<String, int> balancesOf(List<FundTxn> txns) {
  final out = <String, int>{};
  for (final t in txns) {
    out[t.fundId] = (out[t.fundId] ?? 0) + t.amount;
  }
  return out;
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

final taxFundsProvider = StreamProvider<List<SavingsFund>>((ref) {
  return ref.watch(taxRepositoryProvider).watchFunds();
});

final taxFundTxnsProvider = StreamProvider<List<FundTxn>>((ref) {
  return ref.watch(taxRepositoryProvider).watchFundTxns();
});

/// Balances per envelope, recomputed from the ledger on every change.
final taxFundBalancesProvider = Provider<Map<String, int>>((ref) {
  final txns = ref.watch(taxFundTxnsProvider).valueOrNull ?? const [];
  return balancesOf(txns);
});
