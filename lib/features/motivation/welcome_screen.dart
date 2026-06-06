import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/navigation/app_router.dart';
import 'quotes.dart';

/// Full-screen motivational splash shown every time the app opens.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const _gold = Color(0xFFC9A227);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(quoteDeckProvider);
    final deckState = deck.valueOrNull;
    final quote = deckState?.quote;

    void enter() => context.go(Routes.dashboard);
    void nextQuote() {
      if (deckState == null) return;
      ref.read(quoteDeckProvider.notifier).advance();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.space) {
            enter();
          } else {
            nextQuote();
          }
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: nextQuote,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 18),
                  child: child,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 48, height: 3, color: _gold),
                      const SizedBox(height: 40),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 560),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child:
                                SlideTransition(position: slide, child: child),
                          );
                        },
                        child: quote == null
                            ? const _LoadingQuoteBlock(key: ValueKey('loading'))
                            : _QuoteBlock(
                                key: ValueKey(
                                    '${quote.text}-${deckState?.seenToday ?? 0}'),
                                quote: quote,
                              ),
                      ),
                      const SizedBox(height: 56),
                      Text(
                        deckState == null
                            ? 'PREPARING TODAY'
                            : 'QUOTE ${deckState.seenToday} OF ${deckState.total} TODAY',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3,
                          color: Colors.white.withValues(alpha: 0.34),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _KeyHint(label: 'SPACE', value: 'LOCK IN'),
                          _KeyHint(label: 'ANY OTHER KEY', value: 'NEXT QUOTE'),
                        ],
                      ),
                      if (deckState?.repeatedAfterDailyPool ?? false) ...[
                        const SizedBox(height: 18),
                        Text(
                          'FULL DAILY POOL READ - RESHUFFLING',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: _gold.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingQuoteBlock extends StatelessWidget {
  const _LoadingQuoteBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              color: WelcomeScreen._gold, strokeWidth: 2),
        ),
        SizedBox(height: 28),
        Text(
          'Preparing today',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 20,
            fontStyle: FontStyle.italic,
            color: WelcomeScreen._gold,
          ),
        ),
      ],
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '"${quote.text}"',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 42,
            height: 1.28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          '- ${quote.author}',
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 20,
            fontStyle: FontStyle.italic,
            color: WelcomeScreen._gold,
          ),
        ),
      ],
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.8,
                color: WelcomeScreen._gold.withValues(alpha: 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
