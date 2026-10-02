import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../presentation/navigation/app_router.dart';
import '../../presentation/shell/window_bar.dart';
import '../../presentation/widgets/common/living_backdrop.dart';
import '../../presentation/widgets/common/ui_kit.dart';
import '../settings/user_name_dialog.dart';
import 'quotes.dart';

/// Full-screen motivational splash shown every time the app opens.
/// Deep dawn for the welcome stage: indigo night, violet, a warm horizon.
const _welcomePalette = AuroraPalette(
  AppleColors.indigo,
  AppleColors.purple,
  AppleColors.orange,
  AppleColors.pink,
);

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  static const _gold = Color(0xFFC9A227);

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _namePromptChecked = false;
  bool _nameDialogOpen = false;

  Future<void> _promptForNameIfNeeded() async {
    if (!mounted || _nameDialogOpen) return;

    final settings = ref.read(settingsRepositoryProvider);
    final alreadyPrompted = await settings.hasPromptedForUserName();
    final userName = await settings.getUserName();
    if (!mounted || alreadyPrompted || userName != null) return;

    setState(() => _nameDialogOpen = true);
    try {
      final name = await showUserNameDialog(context, firstRun: true);
      if (name != null) {
        await settings.setUserName(name);
      }
      await settings.markUserNamePrompted();
    } finally {
      if (mounted) setState(() => _nameDialogOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider);
    if (!_namePromptChecked && userName.hasValue) {
      _namePromptChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptForNameIfNeeded();
      });
    }

    final deck = ref.watch(quoteDeckProvider);
    final deckState = deck.valueOrNull;
    final quote = deckState?.quote;
    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width < 720 ? 24.0 : 56.0;
    final quoteFontSize = size.width < 720
        ? 30.0
        : size.width < 1040
            ? 38.0
            : 42.0;
    final authorFontSize = size.width < 720 ? 17.0 : 20.0;

    void enter() => context.go(Routes.dashboard);
    void nextQuote() {
      if (deckState == null) return;
      ref.read(quoteDeckProvider.notifier).advance();
    }

    // A cinematic, always-dark stage: the living aurora in deep dawn hues
    // behind the quote, with the frameless window's controls overlaid.
    return Theme(
      data: AppTheme.dark,
      child: Stack(
      children: [
        Positioned.fill(
          child: Scaffold(
            backgroundColor: Colors.black,
            body: LivingBackdrop(
              palette: _welcomePalette,
              intensity: 0.7,
              child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (_nameDialogOpen) return KeyEventResult.ignored;
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
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 32,
                      ),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width < 720 ? 0 : 8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SpringBuilder(
                                  value: 48,
                                  from: 0,
                                  spring: AppSprings.gentle,
                                  builder: (context, w, _) => Container(
                                    width: w.clamp(0.0, 60.0),
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: WelcomeScreen._gold,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.pill),
                                      boxShadow: [
                                        BoxShadow(
                                          color: WelcomeScreen._gold
                                              .withValues(alpha: 0.6),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                                      child: SlideTransition(
                                        position: slide,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: quote == null
                                      ? const _LoadingQuoteBlock(
                                          key: ValueKey('loading'),
                                        )
                                      : _QuoteBlock(
                                          key: ValueKey(
                                            '${quote.text}-${deckState?.seenToday ?? 0}',
                                          ),
                                          quote: quote,
                                          quoteFontSize: quoteFontSize,
                                          authorFontSize: authorFontSize,
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
                                // Desktop drives this screen from the keyboard; touch
                                // devices have no SPACE key, so they get an explicit
                                // "enter" button plus a tap-to-shuffle hint.
                                if (isDesktopPlatform)
                                  const Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _KeyHint(
                                          label: 'SPACE', value: 'LOCK IN'),
                                      _KeyHint(
                                        label: 'ANY OTHER KEY',
                                        value: 'NEXT QUOTE',
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      FilledButton(
                                        onPressed: enter,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: WelcomeScreen._gold,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 40, vertical: 16),
                                          shape: const StadiumBorder(),
                                        ),
                                        child: const Text(
                                          'LOCK IN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'TAP ANYWHERE FOR THE NEXT QUOTE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          letterSpacing: 2,
                                          color: Colors.white
                                              .withValues(alpha: 0.34),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (deckState?.repeatedAfterDailyPool ??
                                    false) ...[
                                  const SizedBox(height: 18),
                                  Text(
                                    'FULL DAILY POOL READ - RESHUFFLING',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      color: WelcomeScreen._gold
                                          .withValues(alpha: 0.7),
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
              ),
            ),
            ),
          ),
        ),
        const Positioned(top: 0, left: 0, right: 0, child: WindowBar()),
      ],
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
  const _QuoteBlock({
    super.key,
    required this.quote,
    required this.quoteFontSize,
    required this.authorFontSize,
  });

  final Quote quote;
  final double quoteFontSize;
  final double authorFontSize;

  @override
  Widget build(BuildContext context) {
    final words = '“${quote.text}”'.split(RegExp(r'\s+'));
    final style = TextStyle(
      fontFamily: 'Georgia',
      fontSize: quoteFontSize,
      height: 1.28,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Each word materialises in turn — blur, rise, settle.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: quoteFontSize * 0.26,
          runSpacing: quoteFontSize * 0.08,
          children: [
            for (final (i, word) in words.indexed)
              Entrance(
                delay: Duration(milliseconds: 90 + 38 * i),
                offset: 14,
                blur: 10,
                scale: 0.97,
                child: Text(word, style: style),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Entrance(
          delay: Duration(milliseconds: 260 + 38 * words.length),
          blur: 6,
          child: Text(
            '— ${quote.author}',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: authorFontSize,
              fontStyle: FontStyle.italic,
              color: WelcomeScreen._gold,
            ),
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
