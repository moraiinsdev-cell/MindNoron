import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/inbox_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../presentation/navigation/app_router.dart';
import '../../presentation/navigation/destinations.dart';
import '../../presentation/shell/sidebar.dart';
import '../../presentation/shell/window_bar.dart';
import '../../presentation/widgets/common/ui_kit.dart';
import '../capture/capture_dialog.dart';
import '../timer/timer_controller.dart';

/// Spotlight-style command palette. Summoned with Ctrl+K or the toolbar pill.
///
/// The app behind blurs and dims as a frosted glass panel springs in; type to
/// fuzzy-search destinations, actions, tasks, notes and inbox items; arrow
/// keys move a sliding highlight, Enter runs, Esc closes.
Future<void> showCommandPalette(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close command palette',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (_, __, ___) => const CommandPalette(),
    transitionBuilder: (context, animation, _, child) {
      final reduced = AppMotion.reduced(context);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      // A whisper of overshoot on the way in — the iOS "pop".
      final pop = CurvedAnimation(
        parent: animation,
        curve: AppMotion.spring,
        reverseCurve: Curves.easeInCubic,
      );
      return Stack(
        children: [
          // The app behind recedes: blur + dim, both animated.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: fade,
                builder: (context, _) {
                  final t = fade.value;
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: reduced ? 0 : 10 * t,
                      sigmaY: reduced ? 0 : 10 * t,
                    ),
                    child: ColoredBox(
                      color: Colors.black
                          .withValues(alpha: (dark ? 0.40 : 0.18) * t),
                    ),
                  );
                },
              ),
            ),
          ),
          FadeTransition(
            opacity: fade,
            child: reduced
                ? child
                : AnimatedBuilder(
                    animation: pop,
                    child: child,
                    builder: (context, child) => Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.translationValues(
                          0, (1 - pop.value) * -10, 0)
                        ..scaleByDouble(0.94 + 0.06 * pop.value,
                            0.94 + 0.06 * pop.value, 1, 1),
                      child: child,
                    ),
                  ),
          ),
        ],
      );
    },
  );
}

enum _Section { goTo, actions, tasks, notes, inbox }

extension on _Section {
  String get title => switch (this) {
        _Section.goTo => 'Go to',
        _Section.actions => 'Actions',
        _Section.tasks => 'Tasks',
        _Section.notes => 'Notes',
        _Section.inbox => 'Inbox',
      };
}

class _Command {
  const _Command({
    required this.section,
    required this.icon,
    required this.color,
    required this.label,
    required this.run,
    this.keywords = '',
    this.hint,
  });

  final _Section section;
  final IconData icon;
  final Color color;
  final String label;
  final String keywords;

  /// Right-aligned hint: a shortcut or the item type.
  final String? hint;
  final VoidCallback run;
}

/// Subsequence fuzzy score: every query char must appear in order. Rewards
/// prefix hits, word starts and consecutive runs. Null = no match.
double? _fuzzy(String query, String text) {
  if (query.isEmpty) return 0;
  final q = query.toLowerCase();
  final s = text.toLowerCase();
  if (s.startsWith(q)) return 1000.0 - s.length;
  final idx = s.indexOf(q);
  if (idx >= 0) {
    final wordStart = idx == 0 || s[idx - 1] == ' ';
    return (wordStart ? 800.0 : 600.0) - idx;
  }
  var score = 0.0;
  var qi = 0;
  var run = 0;
  for (var i = 0; i < s.length && qi < q.length; i++) {
    if (s[i] == q[qi]) {
      qi++;
      run++;
      score += 10 + run * 5 + ((i == 0 || s[i - 1] == ' ') ? 15 : 0);
    } else {
      run = 0;
    }
  }
  return qi == q.length ? score : null;
}

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  static const _rowHeight = 46.0;
  static const _headerHeight = 30.0;

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  int _selected = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  _Command _nav(AppDestination d, int index) => _Command(
        section: _Section.goTo,
        icon: d.icon,
        color: d.color,
        label: d.label,
        keywords: d.keywords,
        hint: index < 9 ? 'Ctrl ${index + 1}' : null,
        run: () {
          Navigator.of(context).pop();
          appRouter.go(d.route);
        },
      );

  int get _workMinutes =>
      ref.watch(workMinutesProvider).valueOrNull ??
      AppConstants.defaultWorkMinutes;

  List<_Command> _commands() {
    final q = _query.trim();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final all = AppDestinations.all;
    final base = <_Command>[
      for (var i = 0; i < all.length; i++) _nav(all[i], i),
      _Command(
        section: _Section.actions,
        icon: Icons.add_rounded,
        color: AppleColors.blue,
        label: 'Quick capture',
        keywords: 'new add note idea',
        run: () {
          Navigator.of(context).pop();
          final c = rootNavigatorKey.currentContext;
          if (c != null) showCaptureDialog(c);
        },
      ),
      _Command(
        section: _Section.actions,
        icon: Icons.play_arrow_rounded,
        color: AppleColors.indigo,
        label: 'Start $_workMinutes min focus',
        keywords: 'timer pomodoro session begin',
        run: () {
          ref
              .read(timerControllerProvider.notifier)
              .start(duration: Duration(minutes: _workMinutes));
          Navigator.of(context).pop();
          appRouter.go(Routes.timer);
        },
      ),
      _Command(
        section: _Section.actions,
        icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: AppleColors.gray,
        label: dark ? 'Switch to light appearance' : 'Switch to dark appearance',
        keywords: 'theme mode appearance',
        run: () {
          ref
              .read(settingsRepositoryProvider)
              .setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
          Navigator.of(context).pop();
        },
      ),
      _Command(
        section: _Section.actions,
        icon: Icons.view_sidebar_rounded,
        color: AppleColors.gray,
        label: 'Toggle sidebar',
        keywords: 'collapse expand navigation',
        hint: 'Ctrl \\',
        run: () {
          final n = ref.read(sidebarCollapsedProvider.notifier);
          final wide = MediaQuery.sizeOf(context).width >=
              kSidebarAutoExpandWidth;
          final expanded = n.state == null ? wide : !n.state!;
          n.state = expanded;
          Navigator.of(context).pop();
        },
      ),
    ];

    if (q.isEmpty) return base;

    final scored = <(double, _Command)>[];
    for (final c in base) {
      // Labels match fuzzily; keywords only by word prefix — a subsequence
      // over a bag of synonyms matches nearly anything.
      final a = _fuzzy(q, c.label);
      final lower = q.toLowerCase();
      final kw = c.keywords.split(' ').any((w) => w.startsWith(lower));
      final s = a ?? (kw ? 300.0 : null);
      if (s != null) scored.add((s, c));
    }

    void addContent(_Section section, IconData icon, Color color,
        Iterable<(String, String)> items, String route) {
      final hits = <(double, _Command)>[];
      for (final (title, body) in items) {
        final s = _fuzzy(q, title) ?? (_fuzzy(q, body) == null ? null : 1.0);
        if (s == null) continue;
        hits.add((
          s,
          _Command(
            section: section,
            icon: icon,
            color: color,
            label: title,
            run: () {
              Navigator.of(context).pop();
              appRouter.go(route);
            },
          ),
        ));
      }
      hits.sort((x, y) => y.$1.compareTo(x.$1));
      scored.addAll(hits.take(5));
    }

    final tasks = ref.watch(openTasksProvider).valueOrNull ?? const <Task>[];
    addContent(_Section.tasks, AppDestinations.tasks.icon,
        AppDestinations.tasks.color, tasks.map((t) => (t.title, '')),
        Routes.tasks);
    final notes = ref.watch(allNotesProvider).valueOrNull ?? const <Note>[];
    addContent(
        _Section.notes,
        AppDestinations.notes.icon,
        AppDestinations.notes.color,
        notes.map((n) => (n.title.isEmpty ? '(untitled)' : n.title, n.content)),
        Routes.notes);
    final inbox =
        ref.watch(unprocessedInboxProvider).valueOrNull ?? const <InboxItem>[];
    addContent(_Section.inbox, AppDestinations.inbox.icon,
        AppDestinations.inbox.color, inbox.map((i) => (i.content, '')),
        Routes.inbox);

    // Sections keep their order; best matches first within each.
    final bySection = <_Section, List<(double, _Command)>>{};
    for (final e in scored) {
      (bySection[e.$2.section] ??= []).add(e);
    }
    return [
      for (final s in _Section.values)
        ...?(bySection[s]?..sort((x, y) => y.$1.compareTo(x.$1)))
            ?.map((e) => e.$2),
    ];
  }

  /// Top offset of [index] in the list, accounting for section headers.
  double _offsetOf(List<_Command> commands, int index) {
    var y = 0.0;
    _Section? last;
    for (var i = 0; i <= index && i < commands.length; i++) {
      if (commands[i].section != last) {
        y += _headerHeight;
        last = commands[i].section;
      }
      if (i < index) y += _rowHeight;
    }
    return y;
  }

  void _move(List<_Command> commands, int delta) {
    if (commands.isEmpty) return;
    setState(() {
      _selected = (_selected + delta) % commands.length;
      if (_selected < 0) _selected += commands.length;
    });
    // Keep the highlight in view.
    if (!_scroll.hasClients) return;
    final top = _offsetOf(commands, _selected);
    final view = _scroll.position.viewportDimension;
    final target = top - _headerHeight < _scroll.offset
        ? top - _headerHeight
        : top + _rowHeight > _scroll.offset + view
            ? top + _rowHeight - view
            : null;
    if (target != null) {
      _scroll.animateTo(
        target.clamp(0, _scroll.position.maxScrollExtent),
        duration: AppMotion.base,
        curve: AppMotion.ease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final commands = _commands();
    if (_selected >= commands.length) _selected = 0;

    final rows = <Widget>[];
    _Section? last;
    for (var i = 0; i < commands.length; i++) {
      final c = commands[i];
      if (c.section != last) {
        last = c.section;
        rows.add(SizedBox(
          height: _headerHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(
              c.section.title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ));
      }
      rows.add(_ResultRow(
        command: c,
        selected: i == _selected,
        height: _rowHeight,
        onHover: () {
          if (_selected != i) setState(() => _selected = i);
        },
      ));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _close,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _move(commands, 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(commands, -1),
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 84, left: 24, right: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
            child: Material(
              type: MaterialType.transparency,
              child: GlassSurface(
                frosted: true,
                level: GlassLevel.thick,
                radius: AppRadii.lg,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search field.
                    SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          const SizedBox(width: 18),
                          Icon(Icons.search_rounded,
                              size: 24, color: cs.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.3,
                              ),
                              cursorColor: cs.primary,
                              onChanged: (v) => setState(() {
                                _query = v;
                                _selected = 0;
                              }),
                              onSubmitted: (_) {
                                if (commands.isNotEmpty) {
                                  commands[_selected].run();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Search MindNoron',
                                hintStyle: theme.textTheme.titleLarge?.copyWith(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isCollapsed: true,
                              ),
                            ),
                          ),
                          const KeyHint('esc'),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                    Divider(
                        height: 1,
                        color: cs.onSurface.withValues(alpha: 0.08)),
                    // Results — the panel grows/shrinks with them.
                    Flexible(
                      child: AnimatedSize(
                        duration: AppMotion.base,
                        curve: AppMotion.ease,
                        alignment: Alignment.topCenter,
                        child: commands.isEmpty
                            ? _EmptyResults(query: _query)
                            : ListView(
                                controller: _scroll,
                                shrinkWrap: true,
                                padding:
                                    const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                children: [
                                  Stack(
                                    children: [
                                      _Highlight(
                                        top: _offsetOf(commands, _selected),
                                        height: _rowHeight,
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: rows,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                    Divider(
                        height: 1,
                        color: cs.onSurface.withValues(alpha: 0.08)),
                    const _Footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The selection highlight: a tinted squircle that springs between rows.
class _Highlight extends StatelessWidget {
  const _Highlight({required this.top, required this.height});

  final double top;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SpringBuilder(
      value: top,
      spring: AppSprings.snappy,
      builder: (context, y, _) => Positioned(
        top: y,
        left: 0,
        right: 0,
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: cs.primary.withValues(alpha: 0.16),
            shape: AppShapes.squircle(
              AppRadii.md,
              side: BorderSide(color: cs.primary.withValues(alpha: 0.22)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.command,
    required this.selected,
    required this.height,
    required this.onHover,
  });

  final _Command command;
  final bool selected;
  final double height;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return MouseRegion(
      onHover: (_) => onHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: command.run,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              const SizedBox(width: 10),
              IconChip(
                icon: command.icon,
                color: command.color,
                size: 28,
                solid: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  command.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (command.hint != null) ...[
                const SizedBox(width: 8),
                KeyHint(command.hint!),
              ],
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: AppMotion.fast,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: Icon(Icons.keyboard_return_rounded,
                      size: 16, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 36, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(
            'No results for “$query”',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget hint(String key, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyHint(key),
            const SizedBox(width: 6),
            Text(label, style: style),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          hint('↑↓', 'navigate'),
          const SizedBox(width: 16),
          hint('↵', 'open'),
          const Spacer(),
          hint('Ctrl K', 'toggle'),
        ],
      ),
    );
  }
}
