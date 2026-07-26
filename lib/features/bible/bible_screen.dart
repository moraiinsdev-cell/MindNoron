import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import '../../presentation/widgets/common/ui_kit.dart';
import 'bible_repository.dart';
import 'bible_verse.dart';

/// Warm, liturgical gold — the identity colour of the Holy Bible hub, kept
/// distinct from Catalyst's amber and the app's teal primary.
const Color kBibleGold = Color(0xFFD9B24C);

/// Offline "Kinh Thánh" hub — a verse of God for every day.
///
/// No network, no LLM. The Today tab features the deterministic daily verse
/// with a short reflection; Chủ đề browses the library by theme; Yêu thích
/// keeps the verses the reader saved. A Vietnamese/English toggle switches
/// between the Bản Truyền Thống and KJV wording throughout.
class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key});

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

enum _Tab { today, topics, favorites }

class _BibleScreenState extends ConsumerState<BibleScreen> {
  _Tab _tab = _Tab.today;
  BibleTopic? _topicFilter;

  @override
  void initState() {
    super.initState();
    // Record the visit once the first frame is up, so opening the Word keeps
    // the daily streak alive without blocking the build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bibleRepositoryProvider).recordVisit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final english = ref.watch(bibleEnglishProvider).valueOrNull ?? false;

    return SectionScaffold(
      icon: Icons.menu_book_rounded,
      accent: kBibleGold,
      title: 'Kinh Thánh',
      subtitle: 'Lời của Chúa cho mỗi ngày — song ngữ, hoàn toàn offline.',
      actions: [
        _LanguageToggle(
          english: english,
          onChanged: (v) => ref.read(bibleRepositoryProvider).setEnglish(v),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_Tab>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _Tab.today,
                icon: Icon(Icons.wb_sunny_outlined),
                label: Text('Hôm nay'),
              ),
              ButtonSegment(
                value: _Tab.topics,
                icon: Icon(Icons.grid_view_outlined),
                label: Text('Chủ đề'),
              ),
              ButtonSegment(
                value: _Tab.favorites,
                icon: Icon(Icons.favorite_outline),
                label: Text('Yêu thích'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (_tab) {
              _Tab.today => _TodayTab(english: english),
              _Tab.topics => _TopicsTab(
                  english: english,
                  filter: _topicFilter,
                  onFilter: (t) => setState(() => _topicFilter = t),
                ),
              _Tab.favorites => _FavoritesTab(english: english),
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Language toggle ───────────────────────────

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.english, required this.onChanged});

  final bool english;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(value: false, label: Text('Tiếng Việt')),
        ButtonSegment(value: true, label: Text('English')),
      ],
      selected: {english},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ─────────────────────────────────── Today ─────────────────────────────────

class _TodayTab extends ConsumerWidget {
  const _TodayTab({required this.english});

  final bool english;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verse = ref.watch(todayVerseProvider);
    final streak = ref.watch(bibleStreakProvider).valueOrNull ?? 0;
    final isDaily = verse.id == verseOfDay().id;

    return ListView(
      children: [
        _StreakStrip(streak: streak, verseCount: bibleVerses.length),
        const SizedBox(height: 16),
        _HeroVerse(verse: verse, english: english, isDaily: isDaily),
        const SizedBox(height: 14),
        _ReflectionCard(verse: verse),
        const SizedBox(height: 14),
        _VerseActions(verse: verse, english: english),
        const SizedBox(height: 16),
        const _SourceNote(),
      ],
    );
  }
}

/// A calm "time in the Word" banner: the daily streak and library size.
class _StreakStrip extends StatelessWidget {
  const _StreakStrip({required this.streak, required this.verseCount});

  final int streak;
  final int verseCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final streakLabel = streak <= 1
        ? 'Bắt đầu hành trình cùng Lời Chúa hôm nay'
        : '$streak ngày liên tiếp bên Lời Chúa';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: cs.panel(),
      child: Row(
        children: [
          Text(streak > 1 ? '🔥' : '🌱', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              streakLabel,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          InfoPill(
            label: '$verseCount câu',
            icon: Icons.auto_stories_outlined,
            color: kBibleGold,
          ),
        ],
      ),
    );
  }
}

/// The hero card: a large, editorial rendering of the featured verse.
class _HeroVerse extends StatelessWidget {
  const _HeroVerse({
    required this.verse,
    required this.english,
    required this.isDaily,
  });

  final BibleVerse verse;
  final bool english;
  final bool isDaily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AccentCard(
      accent: kBibleGold,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InfoPill(
                label: isDaily ? 'Câu của ngày' : 'Câu bạn chọn',
                icon: isDaily ? Icons.wb_sunny_outlined : Icons.casino_outlined,
                color: kBibleGold,
                filled: true,
              ),
              const Spacer(),
              InfoPill(label: '${verse.topic.emoji} ${verse.topic.label}'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '“',
            style: TextStyle(
              fontSize: 44,
              height: 0.6,
              fontWeight: FontWeight.w700,
              color: kBibleGold.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 2),
          // AnimatedSwitcher gives a gentle cross-fade when the verse or the
          // language changes.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Text(
              verse.textFor(english: english),
              key: ValueKey('${verse.id}-$english'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.55,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 22,
                height: 2,
                color: kBibleGold.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Text(
                verse.refFor(english: english),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                english ? 'KJV' : 'BTT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.verse});

  final BibleVerse verse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.self_improvement_outlined,
                color: kBibleGold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suy niệm hôm nay',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    verse.reflection,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four actions on the daily verse: copy, favourite, draw another, and
/// keep it in today's journal.
class _VerseActions extends ConsumerWidget {
  const _VerseActions({required this.verse, required this.english});

  final BibleVerse verse;
  final bool english;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(bibleFavoriteIdsProvider).valueOrNull ?? const [];
    final isFav = favorites.contains(verse.id);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _copy(context, verse, english),
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          label: const Text('Sao chép'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(bibleRepositoryProvider).toggleFavorite(verse.id),
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_outline,
            size: 18,
            color: isFav ? cs(context).error : null,
          ),
          label: Text(isFav ? 'Đã lưu' : 'Yêu thích'),
        ),
        OutlinedButton.icon(
          onPressed: () => _drawAnother(ref, verse),
          icon: const Icon(Icons.casino_outlined, size: 18),
          label: const Text('Câu khác'),
        ),
        OutlinedButton.icon(
          onPressed: () => _saveToJournal(context, ref, verse, english),
          icon: const Icon(Icons.auto_stories_outlined, size: 18),
          label: const Text('Lưu vào Nhật ký'),
        ),
      ],
    );
  }

  ColorScheme cs(BuildContext c) => Theme.of(c).colorScheme;

  Future<void> _copy(
      BuildContext context, BibleVerse v, bool english) async {
    await Clipboard.setData(ClipboardData(text: shareTextFor(v, english)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép câu Kinh Thánh')));
  }

  void _drawAnother(WidgetRef ref, BibleVerse current) {
    if (bibleVerses.length <= 1) return;
    final rng = Random();
    BibleVerse next;
    do {
      next = bibleVerses[rng.nextInt(bibleVerses.length)];
    } while (next.id == current.id);
    ref.read(bibleShuffleProvider.notifier).state = next.id;
  }

  Future<void> _saveToJournal(
    BuildContext context,
    WidgetRef ref,
    BibleVerse v,
    bool english,
  ) async {
    final repo = ref.read(dailyLogRepositoryProvider);
    final today = await repo.watchToday().first;
    final existing = today?.note?.trim() ?? '';
    final entry = '📖 ${v.refFor(english: english)}\n'
        '"${v.textFor(english: english)}"';
    final next = existing.isEmpty ? entry : '$existing\n\n$entry';
    await repo.setNote(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu câu vào Nhật ký hôm nay')));
  }
}

/// Formatted for the clipboard: the verse in quotes, then its reference.
String shareTextFor(BibleVerse v, bool english) =>
    '"${v.textFor(english: english)}"\n— ${v.refFor(english: english)}';

class _SourceNote extends StatelessWidget {
  const _SourceNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bibleSourceNote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────── Topics ────────────────────────────────

class _TopicsTab extends StatelessWidget {
  const _TopicsTab({
    required this.english,
    required this.filter,
    required this.onFilter,
  });

  final bool english;
  final BibleTopic? filter;
  final ValueChanged<BibleTopic?> onFilter;

  @override
  Widget build(BuildContext context) {
    final verses =
        filter == null ? bibleVerses : versesForTopic(filter!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TopicChip(
              label: 'Tất cả',
              selected: filter == null,
              onTap: () => onFilter(null),
            ),
            for (final t in BibleTopic.values)
              _TopicChip(
                label: '${t.emoji} ${t.label}',
                selected: filter == t,
                onTap: () => onFilter(t),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: verses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _VerseCard(verse: verses[i], english: english),
          ),
        ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: selected
          ? kBibleGold.withValues(alpha: 0.16)
          : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? kBibleGold : cs.outlineVariant,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────── Favorites ──────────────────────────────

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.english});

  final bool english;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verses = ref.watch(bibleFavoriteVersesProvider);
    if (verses.isEmpty) return const _FavoritesEmpty();

    return ListView.separated(
      itemCount: verses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) =>
          _VerseCard(verse: verses[i], english: english),
    );
  }
}

class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBibleGold.withValues(alpha: 0.12),
              border: Border.all(color: kBibleGold.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.favorite_outline,
                size: 34, color: kBibleGold),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có câu nào được lưu',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Chạm ♥ trên bất kỳ câu nào để giữ lại ở đây, đọc lại bất cứ lúc nào.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Shared verse card ─────────────────────────

/// A verse row used by the Topics and Favorites lists: text, reference, topic,
/// and quick copy/favourite actions.
class _VerseCard extends ConsumerWidget {
  const _VerseCard({required this.verse, required this.english});

  final BibleVerse verse;
  final bool english;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final favorites =
        ref.watch(bibleFavoriteIdsProvider).valueOrNull ?? const [];
    final isFav = favorites.contains(verse.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    verse.refFor(english: english),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: kBibleGold,
                    ),
                  ),
                ),
                InfoPill(label: '${verse.topic.emoji} ${verse.topic.label}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              verse.textFor(english: english),
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Sao chép',
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: shareTextFor(verse, english)));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Đã sao chép câu Kinh Thánh')));
                  },
                  icon: Icon(Icons.copy_all_outlined,
                      size: 20, color: cs.onSurfaceVariant),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: isFav ? 'Bỏ lưu' : 'Yêu thích',
                  onPressed: () =>
                      ref.read(bibleRepositoryProvider).toggleFavorite(verse.id),
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_outline,
                    size: 20,
                    color: isFav ? cs.error : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
