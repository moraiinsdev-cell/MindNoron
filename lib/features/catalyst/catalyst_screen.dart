import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../presentation/navigation/app_router.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import '../../presentation/widgets/common/ui_kit.dart';
import 'catalyst_idea.dart';
import 'catalyst_repository.dart';
import 'catalyst_service.dart';

/// AI Idea Catalyst — type a brief, get three breakthrough hackathon concepts
/// from Claude (the app's only online feature). Results are persisted, so past
/// briefs survive restarts. The offline Office idea board is untouched.
class CatalystScreen extends ConsumerStatefulWidget {
  const CatalystScreen({super.key});

  @override
  ConsumerState<CatalystScreen> createState() => _CatalystScreenState();
}

class _CatalystScreenState extends ConsumerState<CatalystScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _errorMsg;
  CatalystUsage? _lastUsage;
  int _sessionTokens = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final brief = _controller.text.trim();
    if (brief.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final apiKey =
          await ref.read(settingsRepositoryProvider).getCatalystApiKey() ?? '';
      final result =
          await ref.read(catalystServiceProvider).generate(brief, apiKey);
      await ref.read(catalystRepositoryProvider).addIdeas(result.ideas);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastUsage = result.usage;
        _sessionTokens += result.usage.total;
      });
    } on CatalystException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = _errorMessage(e.kind);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = 'Something went wrong. Please try again.';
      });
    }
  }

  static String _errorMessage(CatalystError kind) => switch (kind) {
        CatalystError.missingKey =>
          'No API key yet. Add one in Settings to generate ideas.',
        CatalystError.unauthorized =>
          'API key rejected. Check it in Settings.',
        CatalystError.rateLimited =>
          'Rate limited. Wait a moment and try again.',
        CatalystError.refused =>
          'The model declined this brief. Try rephrasing it.',
        CatalystError.network =>
          'Network error or timeout. Check your connection and try again.',
        CatalystError.badResponse => 'Unusable response. Please try again.',
      };

  Future<void> _copy(CatalystIdea idea) async {
    final text = '${idea.conceptName}\n\n'
        'Paradigm shift: ${idea.paradigmShift}\n\n'
        'Core mechanism: ${idea.coreMechanism}\n\n'
        'Asymmetric advantage: ${idea.asymmetricAdvantage}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final ideas = ref.watch(catalystIdeasProvider).valueOrNull ?? const [];
    final hasKey = ref.watch(catalystApiKeyProvider).valueOrNull != null;

    final sorted = [...ideas]..sort((a, b) {
        if (a.starred != b.starred) return a.starred ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return SectionScaffold(
      icon: Icons.auto_awesome_rounded,
      accent: AppTheme.accentAmber,
      title: 'Idea Catalyst',
      subtitle:
          'Enter a brief → 3 breakthrough hackathon ideas (Radical Innovation Engine).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasKey) _MissingKeyBanner(onOpenSettings: _openSettings),
          _InputBar(
            controller: _controller,
            loading: _loading,
            onGenerate: _generate,
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const _LoadingBar(),
          ],
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _errorMsg!, onOpenSettings: _openSettings),
          ],
          if (_lastUsage != null && !_loading) ...[
            const SizedBox(height: 12),
            _UsageLine(last: _lastUsage!, sessionTotal: _sessionTokens),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: sorted.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final idea = sorted[i];
                      return _CatalystCard(
                        idea: idea,
                        initiallyExpanded: i < 3,
                        onStar: () => ref
                            .read(catalystRepositoryProvider)
                            .setStarred(idea.id, !idea.starred),
                        onDismiss: () => ref
                            .read(catalystRepositoryProvider)
                            .dismiss(idea.id),
                        onCopy: () => _copy(idea),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openSettings() => context.go(Routes.settings);
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.loading,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cs.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 18, color: AppTheme.accentAmber),
              const SizedBox(width: 8),
              Text('Idea brief',
                  style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                'Radical Innovation Engine',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'e.g. cut urban air pollution using algae...',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: loading ? null : onGenerate,
              icon: const Icon(Icons.bolt),
              label: const Text('Generate Breakthrough Ideas'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 6),
        Text(
          'Forging ideas… (this can take 10–30 seconds)',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Token spend for the last round + a running session total, so brainstorming
/// stays cost-aware. Fed by the Anthropic response `usage` field.
class _UsageLine extends StatelessWidget {
  const _UsageLine({required this.last, required this.sessionTotal});

  final CatalystUsage last;
  final int sessionTotal;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        InfoPill(
          icon: Icons.bolt_outlined,
          label: 'This round: ${last.outputTokens} out · ${last.inputTokens} in',
          color: AppTheme.accentAmber,
        ),
        InfoPill(
          icon: Icons.data_usage,
          label: 'Session: $sessionTotal tokens',
        ),
      ],
    );
  }
}

class _MissingKeyBanner extends StatelessWidget {
  const _MissingKeyBanner({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.key_off_outlined, color: theme.colorScheme.outline),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Anthropic API key not configured.'),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onOpenSettings});

  final String message;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isKey = message.contains('API key');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          if (isKey)
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: cs.heroGradient(AppTheme.accentAmber),
              border:
                  Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 38, color: AppTheme.accentAmber),
          ),
          const SizedBox(height: 16),
          Text(
            'No ideas yet.\nEnter a brief above and tap “Generate Breakthrough Ideas”.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CatalystCard extends StatelessWidget {
  const _CatalystCard({
    required this.idea,
    required this.initiallyExpanded,
    required this.onStar,
    required this.onDismiss,
    required this.onCopy,
  });

  final CatalystIdea idea;
  final bool initiallyExpanded;
  final VoidCallback onStar;
  final VoidCallback onDismiss;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(idea.id),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Text(idea.starred ? '⭐' : '💥',
              style: const TextStyle(fontSize: 20)),
          title: Text(
            idea.conceptName,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: idea.brief.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'from: ${idea.brief}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
          children: [
            _Section(
              label: '🔭 Paradigm shift',
              body: idea.paradigmShift,
            ),
            _Section(
              label: '⚙️ Core mechanism',
              body: idea.coreMechanism,
            ),
            _Section(
              label: '⚡ Asymmetric advantage',
              body: idea.asymmetricAdvantage,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onStar,
                  icon: Icon(
                    idea.starred ? Icons.star : Icons.star_border,
                    size: 18,
                    color: idea.starred ? const Color(0xFFD9A521) : null,
                  ),
                  label: Text(idea.starred ? 'Saved' : 'Save'),
                ),
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy'),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.outline),
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
