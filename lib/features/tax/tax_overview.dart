/// The two money numbers a freelancer should meet every morning, packaged so
/// the dashboard can show them without re-deriving any tax math of its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/navigation/app_router.dart';
import 'tax_engine.dart';
import 'tax_models.dart';
import 'tax_repository.dart';
import 'tax_savings.dart';

/// Runway and the tax gap, computed from the same inputs the Quỹ tab uses.
class MoneyOverview {
  const MoneyOverview({required this.health, required this.reserve});

  final SavingsHealth health;
  final TaxReserve reserve;

  /// Nothing to say yet — no envelopes funded and no revenue booked. The
  /// dashboard stays quiet rather than showing a row of zeros.
  bool get isEmpty => health.total == 0 && reserve.shouldHaveBanked == 0;
}

final moneyOverviewProvider = Provider<MoneyOverview>((ref) {
  final now = DateTime.now();
  final profile = ref.watch(taxProfileProvider).valueOrNull ?? const TaxProfile();
  final revenue = ref.watch(taxRevenueProvider).valueOrNull ?? const [];
  final funds = ref.watch(taxFundsProvider).valueOrNull ?? defaultFunds();
  final balances = ref.watch(taxFundBalancesProvider);

  final toDate = revenue
      .where((e) => e.year == now.year)
      .fold<int>(0, (sum, e) => sum + e.amount);
  final plan = planRemainingYear(
    revenueToDate: toDate,
    today: now,
    line: profile.line,
  );
  final reserve = computeReserve(
    revenueToDate: toDate,
    projectedAnnualRevenue: plan.projectedYearEnd,
    line: profile.line,
  );

  return MoneyOverview(
    health: computeHealth(
      funds: funds,
      balances: balances,
      monthlySpend: profile.monthlySpend,
      taxShouldHold: reserve.shouldHaveBanked,
    ),
    reserve: reserve,
  );
});

/// A compact strip for the dashboard: how long you last without work, and
/// whether you are currently holding money that belongs to the tax office.
///
/// These two live four clicks deep inside the Tax hub, which is three clicks too
/// far for numbers that should change what you do today.
class MoneyStrip extends ConsumerWidget {
  const MoneyStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overview = ref.watch(moneyOverviewProvider);
    if (overview.isEmpty) return const SizedBox.shrink();

    final health = overview.health;
    final runwayColor = switch (health.level) {
      RunwayLevel.critical => theme.colorScheme.error,
      RunwayLevel.thin => const Color(0xFFD9A521),
      RunwayLevel.ok => theme.colorScheme.primary,
      RunwayLevel.solid => const Color(0xFF2E9E6B),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.tax),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.flight_takeoff,
                  label: 'Sống được không cần việc',
                  value: health.needsSpend
                      ? 'Chưa biết'
                      : '${health.runwayMonths.toStringAsFixed(1)} tháng',
                  hint: health.needsSpend
                      ? 'Nhập chi phí sống ở tab Quỹ'
                      : health.level.label,
                  color: health.needsSpend
                      ? theme.colorScheme.onSurfaceVariant
                      : runwayColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 44,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  icon: Icons.account_balance,
                  label: health.taxOnTrack ? 'Quỹ thuế' : 'Quỹ thuế đang thiếu',
                  value: health.taxOnTrack
                      ? 'Đủ'
                      : _short(health.taxGap),
                  hint: health.taxOnTrack
                      ? 'Đang giữ đủ tiền thuế'
                      : 'Bù ngay lần tiền về tới',
                  color: health.taxOnTrack
                      ? const Color(0xFF2E9E6B)
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: color)),
              Text(hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Đồng in the shortest honest form — a dashboard has no room for nine digits.
String _short(int dong) {
  if (dong >= 1000000000) {
    return '${(dong / 1000000000).toStringAsFixed(1)} tỷ ₫';
  }
  if (dong >= 1000000) return '${(dong / 1000000).round()} triệu ₫';
  if (dong >= 1000) return '${(dong / 1000).round()} nghìn ₫';
  return '$dong ₫';
}
