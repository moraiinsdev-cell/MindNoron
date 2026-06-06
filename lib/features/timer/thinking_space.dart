import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/thoughts_repository.dart';
import '../../presentation/widgets/common/copy_button.dart';

/// The noron-space "thinking flow": jot a thought during a focus/break session
/// and watch today's stream of thoughts build up. Captured thoughts are tagged
/// with the active session so you can see what you were thinking, and when.
class ThinkingSpace extends ConsumerStatefulWidget {
  const ThinkingSpace({
    super.key,
    required this.sessionType,
    this.linkedTaskId,
  });

  /// Active session type, or null when idle (stored as 'none').
  final SessionType? sessionType;
  final String? linkedTaskId;

  @override
  ConsumerState<ThinkingSpace> createState() => _ThinkingSpaceState();
}

class _ThinkingSpaceState extends ConsumerState<ThinkingSpace> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(thoughtsRepositoryProvider).capture(
          content: text,
          sessionType: widget.sessionType?.db ?? 'none',
          linkedTaskId: widget.linkedTaskId,
        );
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final thoughts =
        ref.watch(todayThoughtsProvider).valueOrNull ?? const <Thought>[];

    if (thoughts.length != _lastCount) {
      _lastCount = thoughts.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_outlined,
                  size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('Thinking flow', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (thoughts.isNotEmpty)
                Text('${thoughts.length} today',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: thoughts.isEmpty
                ? _empty(theme, cs)
                : ListView.builder(
                    controller: _scroll,
                    itemCount: thoughts.length,
                    itemBuilder: (_, i) => _ThoughtBubble(thought: thoughts[i]),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'What are you thinking?',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Capture thought',
                onPressed: _submit,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(ThemeData theme, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Capture any thought that surfaces — ideas, distractions, next steps. '
          'They flow here so your mind stays on the work.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ThoughtBubble extends ConsumerWidget {
  const _ThoughtBubble({required this.thought});

  final Thought thought;

  String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  String _badge(String sessionType) => switch (sessionType) {
        'work' => 'Focus',
        'short_break' => 'Short break',
        'long_break' => 'Long break',
        _ => '',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final badge = _badge(thought.sessionType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(thought.content, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(_time(thought.createdAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
              if (badge.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: cs.onSecondaryContainer)),
                ),
              ],
              const Spacer(),
              CopyIconButton(text: thought.content, size: 15),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                iconSize: 15,
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(thoughtsRepositoryProvider).softDelete(thought.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
