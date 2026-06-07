import 'package:flutter/material.dart';

import '../../presentation/widgets/common/section_scaffold.dart';
import 'calendar_item.dart';
import 'calendar_utils.dart';

/// A vertical "Schedule" list grouped by day — Google Calendar's agenda view.
class AgendaView extends StatelessWidget {
  const AgendaView({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  final List<CalendarItem> items;
  final ValueChanged<CalendarItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (items.isEmpty) {
      return const ComingSoon(label: 'Nothing scheduled in this range');
    }

    final groups = <DateTime, List<CalendarItem>>{};
    for (final i in items) {
      (groups[CalendarUtils.dayOnly(i.start)] ??= []).add(i);
    }
    final days = groups.keys.toList()..sort();
    final today = CalendarUtils.dayOnly(DateTime.now());

    return ListView.builder(
      itemCount: days.length,
      itemBuilder: (_, idx) {
        final day = days[idx];
        final dayItems = groups[day]!;
        final isToday = CalendarUtils.sameDay(day, today);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: Row(
                children: [
                  Text(
                    '${CalendarUtils.weekdaysShort[day.weekday - 1]}, '
                    '${CalendarUtils.monthsShort[day.month - 1]} ${day.day}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isToday ? cs.primary : cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Today',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.primary)),
                    ),
                  ],
                ],
              ),
            ),
            for (final item in dayItems)
              _AgendaTile(item: item, onTap: () => onItemTap(item)),
          ],
        );
      },
    );
  }
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({required this.item, required this.onTap});

  final CalendarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final time = item.isAllDay
        ? 'All day'
        : '${CalendarUtils.timeLabel(item.start)} – '
            '${CalendarUtils.timeLabel(item.end)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 116,
              child: Text(time,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
            Container(
              width: 4,
              height: 34,
              margin: const EdgeInsets.only(right: 10, top: 1),
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration:
                          item.isDone ? TextDecoration.lineThrough : null,
                      color: item.isDone ? cs.outline : cs.onSurface,
                    ),
                  ),
                  if (item.isTask)
                    Text('Task',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant))
                  else if (item.event?.location != null)
                    Text(item.event!.location!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
