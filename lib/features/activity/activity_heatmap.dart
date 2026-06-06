import 'package:flutter/material.dart';

/// A GitHub-style contribution heatmap for one calendar [year] — upgraded with
/// value-scaled intensity, hover tooltips, a "today" ring, and a left-to-right
/// reveal animation. Horizontally scrollable; weekday labels stay pinned.
class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({
    super.key,
    required this.values,
    required this.year,
    required this.unit,
    this.cell = 13,
    this.gap = 3,
  });

  /// Day (midnight) → metric value for the year.
  final Map<DateTime, int> values;
  final int year;
  final String unit;
  final double cell;
  final double gap;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  static const _weekdayLabels = {1: 'Mon', 3: 'Wed', 5: 'Fri'};

  @override
  void didUpdateWidget(covariant ActivityHeatmap old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year) _reveal.forward(from: 0);
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Color _cellColor(int value, int max, Color base, Color track) {
    if (value <= 0) return track;
    final frac = max <= 0 ? 1.0 : value / max;
    final alpha = frac >= 0.75
        ? 1.0
        : frac >= 0.5
            ? 0.72
            : frac >= 0.25
                ? 0.5
                : 0.3;
    return Color.alphaBlend(base.withValues(alpha: alpha), track);
  }

  String _dateLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final track = cs.surfaceContainerHighest;
    final base = cs.primary;
    final step = widget.cell + widget.gap;

    final jan1 = DateTime(widget.year);
    final dec31 = DateTime(widget.year, 12, 31);
    final start = jan1.subtract(Duration(days: jan1.weekday % 7)); // Sunday
    final columns = (dec31.difference(start).inDays + 1) / 7;
    final cols = columns.ceil();

    final max = widget.values.values.fold<int>(0, (m, v) => v > m ? v : m);
    final now = DateTime.now();
    final todayDay = DateTime(now.year, now.month, now.day);

    // Month label per column where a new month starts.
    final monthLabels = <int, String>{};
    var lastMonth = -1;
    for (var c = 0; c < cols; c++) {
      final colStart = start.add(Duration(days: c * 7));
      if (colStart.year == widget.year && colStart.month != lastMonth) {
        monthLabels[c] = _months[colStart.month - 1];
        lastMonth = colStart.month;
      }
    }

    final labelColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(height: 16 + widget.gap), // align under month row
        for (var r = 0; r < 7; r++)
          SizedBox(
            height: step,
            child: Text(
              _weekdayLabels[r] ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );

    final grid = AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < cols; c++)
              Opacity(
                opacity: Curves.easeOut
                    .transform(((_reveal.value * cols) - c).clamp(0.0, 1.0)),
                child: Padding(
                  padding: EdgeInsets.only(right: widget.gap),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var r = 0; r < 7; r++)
                        _buildCell(c, r, start, jan1, dec31, todayDay, max,
                            base, track),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelColumn,
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 16,
                  width: cols * step,
                  child: Stack(
                    children: [
                      for (final e in monthLabels.entries)
                        Positioned(
                          left: e.key * step,
                          child: Text(
                            e.value,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    fontSize: 10, color: cs.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: widget.gap),
                grid,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell(
    int c,
    int r,
    DateTime start,
    DateTime jan1,
    DateTime dec31,
    DateTime todayDay,
    int max,
    Color base,
    Color track,
  ) {
    final date = start.add(Duration(days: c * 7 + r));
    final pad = EdgeInsets.only(bottom: widget.gap);
    if (date.isBefore(jan1) || date.isAfter(dec31)) {
      return Padding(
        padding: pad,
        child: SizedBox(width: widget.cell, height: widget.cell),
      );
    }
    final day = DateTime(date.year, date.month, date.day);
    final value = widget.values[day] ?? 0;
    final isToday = day == todayDay;
    final tip =
        value <= 0 ? 'No activity · ${_dateLabel(day)}' : '$value ${widget.unit} · ${_dateLabel(day)}';

    return Padding(
      padding: pad,
      child: Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 300),
        child: Container(
          width: widget.cell,
          height: widget.cell,
          decoration: BoxDecoration(
            color: _cellColor(value, max, base, track),
            borderRadius: BorderRadius.circular(3),
            border: isToday
                ? Border.all(color: base, width: 1.4)
                : null,
          ),
        ),
      ),
    );
  }
}

/// The "Less □ □ □ □ More" intensity legend.
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final track = cs.surfaceContainerHighest;
    final base = cs.primary;
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: cs.onSurfaceVariant, fontSize: 11);
    Widget swatch(double alpha) => Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: alpha == 0
                ? track
                : Color.alphaBlend(base.withValues(alpha: alpha), track),
            borderRadius: BorderRadius.circular(3),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Less', style: style),
        const SizedBox(width: 4),
        swatch(0),
        swatch(0.3),
        swatch(0.5),
        swatch(0.72),
        swatch(1.0),
        const SizedBox(width: 4),
        Text('More', style: style),
      ],
    );
  }
}
