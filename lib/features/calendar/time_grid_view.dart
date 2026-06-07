import 'package:flutter/material.dart';

import 'calendar_item.dart';
import 'calendar_utils.dart';

/// A time-grid (week or day) view: 24 hour rows with positioned event blocks,
/// an all-day header row and a live current-time indicator — the signature
/// Google Calendar layout.
class TimeGridView extends StatefulWidget {
  const TimeGridView({
    super.key,
    required this.days,
    required this.items,
    required this.onSlotTap,
    required this.onItemTap,
  });

  /// Day-start dates to show as columns (1 = day view, 7 = week view).
  final List<DateTime> days;
  final List<CalendarItem> items;
  final ValueChanged<DateTime> onSlotTap;
  final ValueChanged<CalendarItem> onItemTap;

  @override
  State<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends State<TimeGridView> {
  static const _hourHeight = 50.0;
  static const _gutter = 56.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Open scrolled to ~7am so the day's active hours are visible first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo((7 * _hourHeight).clamp(0, _scroll.position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = CalendarUtils.dayOnly(DateTime.now());

    return Column(
      children: [
        // Day headers.
        Row(
          children: [
            const SizedBox(width: _gutter),
            for (final day in widget.days)
              Expanded(child: _DayHeader(day: day, isToday: CalendarUtils.sameDay(day, today))),
          ],
        ),
        const SizedBox(height: 4),
        // All-day row.
        _AllDayRow(
          days: widget.days,
          items: widget.items,
          onItemTap: widget.onItemTap,
          gutter: _gutter,
        ),
        Divider(height: 1, color: cs.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hour gutter.
                  SizedBox(
                    width: _gutter,
                    child: Stack(
                      children: [
                        for (var h = 1; h < 24; h++)
                          Positioned(
                            top: h * _hourHeight - 7,
                            right: 6,
                            child: Text(
                              _hourLabel(h),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final day in widget.days)
                    Expanded(
                      child: _DayColumn(
                        day: day,
                        items: widget.items,
                        hourHeight: _hourHeight,
                        isToday: CalendarUtils.sameDay(day, today),
                        onSlotTap: widget.onSlotTap,
                        onItemTap: widget.onItemTap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _hourLabel(int h) {
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour ${h < 12 ? 'AM' : 'PM'}';
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Text(
          CalendarUtils.weekdaysShort[day.weekday - 1],
          style: theme.textTheme.labelSmall?.copyWith(
            color: isToday ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: isToday
              ? BoxDecoration(color: cs.primary, shape: BoxShape.circle)
              : null,
          child: Text(
            '${day.day}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isToday ? cs.onPrimary : cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AllDayRow extends StatelessWidget {
  const _AllDayRow({
    required this.days,
    required this.items,
    required this.onItemTap,
    required this.gutter,
  });

  final List<DateTime> days;
  final List<CalendarItem> items;
  final ValueChanged<CalendarItem> onItemTap;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 76),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: gutter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 6),
                child: Text('all-day',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Column(
                    children: [
                      for (final item in _allDayFor(day))
                        _AllDayChip(item: item, onTap: () => onItemTap(item)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<CalendarItem> _allDayFor(DateTime day) {
    return items.where((i) {
      if (!i.isAllDay) return false;
      final s = CalendarUtils.dayOnly(i.start);
      final e = CalendarUtils.dayOnly(i.end);
      return !day.isBefore(s) && !day.isAfter(e);
    }).toList();
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({required this.item, required this.onTap});

  final CalendarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          item.isTask ? '◔ ${item.title}' : item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                decoration: item.isDone ? TextDecoration.lineThrough : null,
              ),
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.items,
    required this.hourHeight,
    required this.isToday,
    required this.onSlotTap,
    required this.onItemTap,
  });

  final DateTime day;
  final List<CalendarItem> items;
  final double hourHeight;
  final bool isToday;
  final ValueChanged<DateTime> onSlotTap;
  final ValueChanged<CalendarItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayStart = day;
    final dayEnd = day.add(const Duration(days: 1));
    final timed = _layout(items
        .where((i) =>
            !i.isAllDay &&
            i.start.isBefore(dayEnd) &&
            i.end.isAfter(dayStart))
        .toList());

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) {
            final minutes =
                (d.localPosition.dy / hourHeight * 60).clamp(0, 24 * 60 - 30);
            final rounded = (minutes / 30).floor() * 30;
            onSlotTap(day.add(Duration(minutes: rounded.toInt())));
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                    hourHeight: hourHeight,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              for (final slot in timed)
                _eventBlock(slot, dayStart, dayEnd, width),
              if (isToday) _nowLine(cs),
            ],
          ),
        );
      },
    );
  }

  Widget _eventBlock(_Slot slot, DateTime dayStart, DateTime dayEnd, double width) {
    final item = slot.item;
    final start = item.start.isBefore(dayStart) ? dayStart : item.start;
    final end = item.end.isAfter(dayEnd) ? dayEnd : item.end;
    final top = _minutesFrom(dayStart, start) / 60 * hourHeight;
    final rawH =
        (_minutesFrom(dayStart, end) - _minutesFrom(dayStart, start)) /
            60 *
            hourHeight;
    const gap = 2.0;
    final colW = width / slot.cols;

    return Positioned(
      top: top,
      height: rawH < 20 ? 20 : rawH,
      left: slot.col * colW + gap,
      width: colW - gap * 1.5,
      child: _EventBlock(item: item, onTap: () => onItemTap(item)),
    );
  }

  Widget _nowLine(ColorScheme cs) {
    final now = DateTime.now();
    final top = (now.hour * 60 + now.minute) / 60 * hourHeight;
    return Positioned(
      top: top - 1,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 2, color: cs.error)),
        ],
      ),
    );
  }

  static double _minutesFrom(DateTime base, DateTime t) =>
      t.difference(base).inMinutes.toDouble();

  /// Overlap layout: assign each event a column index + total columns in its
  /// cluster so blocks sit side by side instead of stacking.
  static List<_Slot> _layout(List<CalendarItem> dayItems) {
    if (dayItems.isEmpty) return const [];
    final sorted = [...dayItems]..sort((a, b) => a.start.compareTo(b.start));
    final slots = [for (final i in sorted) _Slot(i)];

    var clusterStart = 0;
    var clusterMaxEnd = sorted.first.end;
    final colEnds = <DateTime>[];

    void finalizeCluster(int endExclusive) {
      final cols = colEnds.length;
      for (var k = clusterStart; k < endExclusive; k++) {
        slots[k].cols = cols < 1 ? 1 : cols;
      }
      colEnds.clear();
    }

    for (var idx = 0; idx < sorted.length; idx++) {
      final item = sorted[idx];
      if (item.start.isAfter(clusterMaxEnd) ||
          item.start.isAtSameMomentAs(clusterMaxEnd)) {
        finalizeCluster(idx);
        clusterStart = idx;
        clusterMaxEnd = item.end;
      }
      // place in first free column
      var placed = false;
      for (var c = 0; c < colEnds.length; c++) {
        if (!item.start.isBefore(colEnds[c])) {
          colEnds[c] = item.end;
          slots[idx].col = c;
          placed = true;
          break;
        }
      }
      if (!placed) {
        slots[idx].col = colEnds.length;
        colEnds.add(item.end);
      }
      if (item.end.isAfter(clusterMaxEnd)) clusterMaxEnd = item.end;
    }
    finalizeCluster(sorted.length);
    return slots;
  }
}

class _EventBlock extends StatelessWidget {
  const _EventBlock({required this.item, required this.onTap});

  final CalendarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(5),
          border: Border(left: BorderSide(color: item.color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              CalendarUtils.timeLabel(item.start),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slot {
  _Slot(this.item);
  final CalendarItem item;
  int col = 0;
  int cols = 1;
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.hourHeight, required this.color});

  final double hourHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var h = 0; h <= 24; h++) {
      final y = h * hourHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // left edge
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.hourHeight != hourHeight || old.color != color;
}
