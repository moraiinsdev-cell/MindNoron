import 'package:flutter/material.dart';

import 'calendar_item.dart';
import 'calendar_utils.dart';

/// A Google-Calendar-style month grid: 6 weeks of day cells with event chips.
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.anchor,
    required this.items,
    required this.onDayTap,
    required this.onItemTap,
  });

  /// Any date inside the month being shown.
  final DateTime anchor;
  final List<CalendarItem> items;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<CalendarItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final firstOfMonth = DateTime(anchor.year, anchor.month, 1);
    final gridStart = CalendarUtils.weekStart(firstOfMonth);
    final days = List.generate(42, (i) => gridStart.add(Duration(days: i)));
    final byDay = _groupByDay(days);
    final today = CalendarUtils.dayOnly(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            for (final w in CalendarUtils.weekdaysShort)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Expanded(
                  child: Row(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Expanded(
                          child: _DayCell(
                            day: days[week * 7 + d],
                            inMonth: days[week * 7 + d].month == anchor.month,
                            isToday: CalendarUtils.sameDay(
                                days[week * 7 + d], today),
                            items: byDay[
                                    CalendarUtils.dayOnly(days[week * 7 + d])] ??
                                const [],
                            onTap: () => onDayTap(days[week * 7 + d]),
                            onItemTap: onItemTap,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Map<DateTime, List<CalendarItem>> _groupByDay(List<DateTime> days) {
    final first = CalendarUtils.dayOnly(days.first);
    final last = CalendarUtils.dayOnly(days.last);
    final map = <DateTime, List<CalendarItem>>{};
    for (final item in items) {
      var d = CalendarUtils.dayOnly(item.start);
      final endDay = CalendarUtils.dayOnly(item.end);
      var guard = 0;
      while (!d.isAfter(endDay) && guard < 60) {
        if (!d.isBefore(first) && !d.isAfter(last)) {
          (map[d] ??= []).add(item);
        }
        d = d.add(const Duration(days: 1));
        guard++;
      }
    }
    return map;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.items,
    required this.onTap,
    required this.onItemTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final List<CalendarItem> items;
  final VoidCallback onTap;
  final ValueChanged<CalendarItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(color: cs.primary, shape: BoxShape.circle)
                    : null,
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isToday
                        ? cs.onPrimary
                        : inMonth
                            ? cs.onSurface
                            : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  const chipH = 17.0;
                  final maxChips = (c.maxHeight / chipH).floor().clamp(0, 6);
                  final shown =
                      items.length > maxChips ? maxChips - 1 : items.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < shown && i < items.length; i++)
                        _Chip(item: items[i], onTap: () => onItemTap(items[i])),
                      if (items.length > shown)
                        Text(
                          '+${items.length - shown} more',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.item, required this.onTap});

  final CalendarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: item.isAllDay ? 0.85 : 0.18),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            if (!item.isAllDay) ...[
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: item.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                item.isTask ? '◔ ${item.title}' : item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: item.isAllDay
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  decoration: item.isDone ? TextDecoration.lineThrough : null,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
