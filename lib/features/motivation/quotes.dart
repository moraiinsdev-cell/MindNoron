import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';

/// A motivational line shown on the welcome splash and the dashboard.
class Quote {
  const Quote(this.text, this.author);

  final String text;
  final String author;
}

class QuoteDeckState {
  const QuoteDeckState({
    required this.quote,
    required this.seenToday,
    required this.total,
    required this.repeatedAfterDailyPool,
  });

  final Quote quote;
  final int seenToday;
  final int total;
  final bool repeatedAfterDailyPool;
}

class _StoredQuoteDeck {
  const _StoredQuoteDeck({
    required this.day,
    required this.order,
    required this.cursor,
    required this.shownToday,
    this.lastQuoteIndex,
  });

  final String day;
  final List<int> order;
  final int cursor;
  final int shownToday;
  final int? lastQuoteIndex;
}

/// Original, app-safe motivation lines. Order does not matter; the daily deck
/// shuffles indexes and persists progress so viewed lines are not repeated
/// during the same day unless the full pool has already been exhausted.
const List<Quote> motivationQuotes = <Quote>[
  Quote("Lock in before the day starts bargaining with you.", "MindNoron"),
  Quote(
      "The first clean minute of focus can rescue the whole day.", "MindNoron"),
  Quote("Do not negotiate with the version of you that wants delay.",
      "MindNoron"),
  Quote("Begin small, begin now, and let momentum do its quiet work.",
      "MindNoron"),
  Quote("Your future is built by the task you stop avoiding.", "MindNoron"),
  Quote("One decisive start beats a hundred perfect plans.", "MindNoron"),
  Quote("Open the work. Touch the first piece. The rest will follow.",
      "MindNoron"),
  Quote("You do not need a mood; you need a starting line.", "MindNoron"),
  Quote("Make the next ten minutes impossible to waste.", "MindNoron"),
  Quote("Show up before confidence arrives.", "MindNoron"),
  Quote("The day changes when you choose the first hard thing.", "MindNoron"),
  Quote("Start with the part you can see. Clarity is earned in motion.",
      "MindNoron"),
  Quote("A locked-in hour is worth more than a distracted afternoon.",
      "MindNoron"),
  Quote("Move first. Motivation often follows footsteps.", "MindNoron"),
  Quote("Today does not need drama. It needs execution.", "MindNoron"),
  Quote("Give the work one honest attempt before you judge the day.",
      "MindNoron"),
  Quote("The door opens after the first uncomfortable step.", "MindNoron"),
  Quote(
      "Do the opening move so your mind has something to follow.", "MindNoron"),
  Quote("You can change the tone of today in the next five minutes.",
      "MindNoron"),
  Quote("Less waiting, more becoming.", "MindNoron"),
  Quote("You are one focused block away from feeling different.", "MindNoron"),
  Quote("Choose the task that would make the day lighter if finished.",
      "MindNoron"),
  Quote("The work gets less scary when it has a timestamp.", "MindNoron"),
  Quote("Put your attention where your ambition keeps pointing.", "MindNoron"),
  Quote("Do not ask if you feel ready. Ask what ready would do.", "MindNoron"),
  Quote("Let action be the proof, not the promise.", "MindNoron"),
  Quote("You only need enough courage to begin the next rep.", "MindNoron"),
  Quote(
      "Make the start so simple that resistance has no argument.", "MindNoron"),
  Quote("The first page, the first line, the first commit: choose one.",
      "MindNoron"),
  Quote("Turn the day from possible into real.", "MindNoron"),
  Quote("Discipline is remembering what matters after the mood changes.",
      "MindNoron"),
  Quote("Consistency is self-respect repeated until it becomes normal.",
      "MindNoron"),
  Quote("The version of you who wins today is built by boring reps.",
      "MindNoron"),
  Quote("Do the repeatable thing. Greatness likes repeatable things.",
      "MindNoron"),
  Quote("Your habits are voting. Make today's vote count.", "MindNoron"),
  Quote(
      "A little done daily becomes a lot that cannot be ignored.", "MindNoron"),
  Quote("Discipline is not intensity. It is returning.", "MindNoron"),
  Quote("Keep promises to yourself when nobody is clapping.", "MindNoron"),
  Quote("Small standards, kept daily, become a strong life.", "MindNoron"),
  Quote(
      "You are training your default setting with every choice.", "MindNoron"),
  Quote("The streak matters less than the return. Return today.", "MindNoron"),
  Quote("Reliable effort turns pressure into progress.", "MindNoron"),
  Quote("Do not chase a perfect day. Build a dependable one.", "MindNoron"),
  Quote("The quiet repeat is where the transformation hides.", "MindNoron"),
  Quote("You are not behind if you are back on task.", "MindNoron"),
  Quote("Make discipline feel ordinary, and progress becomes inevitable.",
      "MindNoron"),
  Quote(
      "What you repeat today is what you become easier tomorrow.", "MindNoron"),
  Quote("No heroic speech required. Just the next disciplined action.",
      "MindNoron"),
  Quote("Your system gets stronger every time you use it under pressure.",
      "MindNoron"),
  Quote("Let routine carry what motivation cannot.", "MindNoron"),
  Quote("If it matters, give it a place on the calendar.", "MindNoron"),
  Quote("The boring plan is often the winning plan.", "MindNoron"),
  Quote("Keep the standard when the day is inconvenient.", "MindNoron"),
  Quote(
      "Discipline is the bridge between your private intent and public result.",
      "MindNoron"),
  Quote("Do not make the habit impressive. Make it unmissable.", "MindNoron"),
  Quote("A stable rhythm beats a dramatic comeback.", "MindNoron"),
  Quote("Protect your baseline. The big days will take care of themselves.",
      "MindNoron"),
  Quote("The goal is not to feel strong. The goal is to act aligned.",
      "MindNoron"),
  Quote("One kept promise today makes tomorrow easier to trust.", "MindNoron"),
  Quote("Consistency turns effort into evidence.", "MindNoron"),
  Quote("Focus is a room you enter by closing other doors.", "MindNoron"),
  Quote("Your attention is expensive. Spend it like it matters.", "MindNoron"),
  Quote("Deep work begins when the easy distractions lose permission.",
      "MindNoron"),
  Quote("One screen, one task, one clean block.", "MindNoron"),
  Quote("The mind settles when the mission is specific.", "MindNoron"),
  Quote("Noise will always volunteer. Choose the signal.", "MindNoron"),
  Quote("Protect the next hour like it is funding your future.", "MindNoron"),
  Quote("Focus is not found. It is defended.", "MindNoron"),
  Quote("The task deserves your full presence or your honest refusal.",
      "MindNoron"),
  Quote("Give your brain fewer tabs and a better target.", "MindNoron"),
  Quote("A clear priority is a kindness to your tired mind.", "MindNoron"),
  Quote("Do not multitask your way out of becoming excellent.", "MindNoron"),
  Quote("Attention becomes power when it stops leaking.", "MindNoron"),
  Quote("Put the phone down. Pick the future up.", "MindNoron"),
  Quote("The world can wait while you do the thing you chose.", "MindNoron"),
  Quote("Focus turns effort from smoke into fire.", "MindNoron"),
  Quote("The strongest move is often removing one distraction.", "MindNoron"),
  Quote("One uninterrupted block can change your belief in yourself.",
      "MindNoron"),
  Quote("Let the work be the only open tab in your head.", "MindNoron"),
  Quote("Today, make concentration your competitive advantage.", "MindNoron"),
  Quote("You cannot steer scattered attention toward a serious goal.",
      "MindNoron"),
  Quote("The task is easier when your attention stops wandering away from it.",
      "MindNoron"),
  Quote("Guard the beginning of a focus block; it sets the whole tone.",
      "MindNoron"),
  Quote("Your best ideas need silence long enough to arrive.", "MindNoron"),
  Quote("Focus is how you tell your future it matters.", "MindNoron"),
  Quote("Do fewer things with more of yourself.", "MindNoron"),
  Quote(
      "A focused mind makes ordinary minutes unusually valuable.", "MindNoron"),
  Quote("Close the loop. Finish the open thing.", "MindNoron"),
  Quote("Make the next block clean enough to be proud of.", "MindNoron"),
  Quote("Do not let urgent noise steal important progress.", "MindNoron"),
  Quote(
      "Difficulty is not a stop sign. It is a training surface.", "MindNoron"),
  Quote("You are allowed to struggle and still be moving correctly.",
      "MindNoron"),
  Quote("The hard part is not proof you should quit.", "MindNoron"),
  Quote("Stay with the problem one breath longer.", "MindNoron"),
  Quote("Resistance is the weight. Progress is the lift.", "MindNoron"),
  Quote(
      "If today feels heavy, make the rep smaller, not optional.", "MindNoron"),
  Quote("The comeback begins as a quiet decision, not a loud moment.",
      "MindNoron"),
  Quote("You can be tired and still be trustworthy.", "MindNoron"),
  Quote("The obstacle is asking for a better method, not a smaller dream.",
      "MindNoron"),
  Quote("Every unfinished attempt taught you where the next one begins.",
      "MindNoron"),
  Quote("Do not confuse slow progress with no progress.", "MindNoron"),
  Quote("The day is not lost while the next action is available.", "MindNoron"),
  Quote("When the work pushes back, push with patience.", "MindNoron"),
  Quote("You have survived harder moments than this blank beginning.",
      "MindNoron"),
  Quote("Progress often feels like friction before it feels like flow.",
      "MindNoron"),
  Quote("Let the setback become data, then get back to work.", "MindNoron"),
  Quote("A rough start can still become a clean finish.", "MindNoron"),
  Quote("Keep going until your effort has a chance to compound.", "MindNoron"),
  Quote(
      "You do not need to win the whole mountain today. Climb the next meter.",
      "MindNoron"),
  Quote("Your patience is part of the skill.", "MindNoron"),
  Quote("Hard days build evidence that you are not fragile.", "MindNoron"),
  Quote("The pressure is real. So is your capacity.", "MindNoron"),
  Quote("Do not abandon the mission because the mood got loud.", "MindNoron"),
  Quote("Turn frustration into one cleaner attempt.", "MindNoron"),
  Quote("The work that humbles you is also upgrading you.", "MindNoron"),
  Quote("A bad minute does not own the next one.", "MindNoron"),
  Quote("You can restart without announcing it. Restart now.", "MindNoron"),
  Quote(
      "Endure the awkward middle. That is where skill is forged.", "MindNoron"),
  Quote("Stay steady. The result is still forming.", "MindNoron"),
  Quote("Every time you return, quitting loses influence.", "MindNoron"),
  Quote("Become the kind of person your calendar can rely on.", "MindNoron"),
  Quote("Your identity is shaped by the standards you practice today.",
      "MindNoron"),
  Quote(
      "Act like the person who already takes the goal seriously.", "MindNoron"),
  Quote(
      "Confidence is built when action keeps meeting resistance.", "MindNoron"),
  Quote("The future you admire is asking for today's discipline.", "MindNoron"),
  Quote("Do the work in a way your future self can respect.", "MindNoron"),
  Quote("You are not waiting to become capable. You become capable by doing.",
      "MindNoron"),
  Quote("Let today's effort make tomorrow's self easier to believe in.",
      "MindNoron"),
  Quote("You can become someone new by keeping one promise at a time.",
      "MindNoron"),
  Quote("The strongest identity is practiced quietly.", "MindNoron"),
  Quote("Stop proving you are busy. Prove you are aligned.", "MindNoron"),
  Quote(
      "Your life follows the standards you stop apologizing for.", "MindNoron"),
  Quote("Be the person who starts before the excuse finishes talking.",
      "MindNoron"),
  Quote("Do not wait for belief. Earn it with a completed block.", "MindNoron"),
  Quote("You are closer to disciplined than your feelings admit.", "MindNoron"),
  Quote("Choose the action your best self would recognize.", "MindNoron"),
  Quote("Private effort is where public confidence is born.", "MindNoron"),
  Quote("Build proof. Feelings can catch up later.", "MindNoron"),
  Quote("Your ambition deserves behavior that matches it.", "MindNoron"),
  Quote(
      "No one can give you the identity you refuse to practice.", "MindNoron"),
  Quote("Let the next task introduce you to yourself again.", "MindNoron"),
  Quote("Become reliable in small things and powerful in large ones.",
      "MindNoron"),
  Quote("The mirror changes after the routine changes.", "MindNoron"),
  Quote("Act from the standard, not from the slump.", "MindNoron"),
  Quote("You are not starting from zero. You are starting from experience.",
      "MindNoron"),
  Quote("Energy follows direction more often than direction follows energy.",
      "MindNoron"),
  Quote("Take care of the body that has to carry the mission.", "MindNoron"),
  Quote("Breathe, choose, execute.", "MindNoron"),
  Quote("Calm is a productivity tool.", "MindNoron"),
  Quote("The day gets lighter when the decision gets simpler.", "MindNoron"),
  Quote("Reduce the chaos to one honest next step.", "MindNoron"),
  Quote(
      "You do not need more pressure. You need a clearer target.", "MindNoron"),
  Quote("Rest when needed, then return without guilt.", "MindNoron"),
  Quote("A steady nervous system can do serious work.", "MindNoron"),
  Quote("Drink water, clear the desk, begin again.", "MindNoron"),
  Quote("Your mind is easier to lead after your environment is cleaner.",
      "MindNoron"),
  Quote("Move with calm urgency.", "MindNoron"),
  Quote("Peace is not passivity. It is focused control.", "MindNoron"),
  Quote("Lower the noise until the next right action is obvious.", "MindNoron"),
  Quote("A grounded start beats a frantic sprint.", "MindNoron"),
  Quote("Do not let stress choose the plan.", "MindNoron"),
  Quote("Your pace can be calm and still be serious.", "MindNoron"),
  Quote("The work respects steady hands.", "MindNoron"),
  Quote("Clear space around the task; your attention will thank you.",
      "MindNoron"),
  Quote("Begin from breath, then build from action.", "MindNoron"),
  Quote("You can be gentle with yourself and strict with the mission.",
      "MindNoron"),
  Quote("Make the environment make the right choice easier.", "MindNoron"),
  Quote("Do not burn the day for the sake of speed.", "MindNoron"),
  Quote("Use calm as fuel, not as an excuse to drift.", "MindNoron"),
  Quote("Your best work arrives when urgency and patience cooperate.",
      "MindNoron"),
  Quote("Purpose turns tasks into training.", "MindNoron"),
  Quote("Remember why the work gets a place in your life.", "MindNoron"),
  Quote("The goal is not somewhere else; it is hidden in today's practice.",
      "MindNoron"),
  Quote("Build the life you keep imagining in quiet moments.", "MindNoron"),
  Quote("If the mission matters, the next hour matters.", "MindNoron"),
  Quote("Make today a receipt for what you say you want.", "MindNoron"),
  Quote("You do not need forever. You need this block.", "MindNoron"),
  Quote(
      "The future is not abstract. It is scheduled or neglected.", "MindNoron"),
  Quote("Your priorities become real when they receive protected time.",
      "MindNoron"),
  Quote("Do the thing that makes your larger life more possible.", "MindNoron"),
  Quote(
      "A meaningful day is often made of unglamorous decisions.", "MindNoron"),
  Quote("The work is not punishment. It is participation in your own becoming.",
      "MindNoron"),
  Quote("Do not let the easy option write your story.", "MindNoron"),
  Quote("Aim the day at something worthy.", "MindNoron"),
  Quote("You owe your dream a cleaner attempt than yesterday.", "MindNoron"),
  Quote("Let the mission simplify the menu of choices.", "MindNoron"),
  Quote("Build toward something you would be proud to inherit.", "MindNoron"),
  Quote("The point of planning is to make courage easier to access.",
      "MindNoron"),
  Quote("What matters deserves more than leftover attention.", "MindNoron"),
  Quote("Give your best hours to your best direction.", "MindNoron"),
  Quote("Today's finish line is the next honest completion.", "MindNoron"),
  Quote("Make progress visible. It will feed the next push.", "MindNoron"),
  Quote("Your dream needs fewer speeches and more timestamps.", "MindNoron"),
  Quote("Let the day end with evidence, not excuses.", "MindNoron"),
  Quote("Do one thing today that makes future regret quieter.", "MindNoron"),
  Quote("Work like your attention is sacred, because it is.", "MindNoron"),
  Quote("Turn desire into proof before the day gets loud.", "MindNoron"),
  Quote("A serious life is assembled from serious minutes.", "MindNoron"),
  Quote("Choose the next action that makes the path feel real.", "MindNoron"),
  Quote("Lock in, then let the work change you.", "MindNoron"),
];

final quoteDeckProvider =
    AsyncNotifierProvider<QuoteDeckController, QuoteDeckState>(
        QuoteDeckController.new);

/// Backwards-compatible provider for screens that only need the current line.
final randomQuoteProvider = Provider<Quote>((ref) {
  return ref.watch(quoteDeckProvider).valueOrNull?.quote ??
      motivationQuotes.first;
});

class QuoteDeckController extends AsyncNotifier<QuoteDeckState> {
  static const _kDay = 'motivation.day';
  static const _kOrder = 'motivation.order';
  static const _kCursor = 'motivation.cursor';
  static const _kShownToday = 'motivation.shownToday';
  static const _kLastQuoteIndex = 'motivation.lastQuoteIndex';

  final Random _random = Random();
  bool _advancing = false;

  @override
  Future<QuoteDeckState> build() async {
    return _consume(await _loadDeck());
  }

  Future<void> advance() async {
    if (_advancing) return;
    _advancing = true;
    try {
      final previousQuote = state.valueOrNull?.quote;
      final previousIndex = previousQuote == null
          ? null
          : motivationQuotes.indexOf(previousQuote);
      state = AsyncData(
        await _consume(
          await _loadDeck(),
          previousQuoteIndex: previousIndex == -1 ? null : previousIndex,
        ),
      );
    } finally {
      _advancing = false;
    }
  }

  Future<_StoredQuoteDeck> _loadDeck() async {
    final settings = ref.read(settingsRepositoryProvider);
    final today = _todayKey(DateTime.now());
    final savedDay = await settings.readValue(_kDay);

    if (savedDay == today) {
      final order = _decodeOrder(await settings.readValue(_kOrder));
      if (order != null) {
        return _StoredQuoteDeck(
          day: today,
          order: order,
          cursor: _parseNonNegative(await settings.readValue(_kCursor)),
          shownToday: _parseNonNegative(await settings.readValue(_kShownToday)),
          lastQuoteIndex:
              _parseOptionalIndex(await settings.readValue(_kLastQuoteIndex)),
        );
      }
    }

    return _StoredQuoteDeck(
      day: today,
      order: _shuffledIndexes(),
      cursor: 0,
      shownToday: 0,
    );
  }

  Future<QuoteDeckState> _consume(
    _StoredQuoteDeck deck, {
    int? previousQuoteIndex,
  }) async {
    var order = deck.order;
    var cursor = deck.cursor;
    var repeatedAfterDailyPool = false;

    if (cursor >= order.length) {
      repeatedAfterDailyPool = true;
      order = _shuffledIndexes(
          avoidFirst: previousQuoteIndex ?? deck.lastQuoteIndex);
      cursor = 0;
    }

    final quoteIndex = order[cursor];
    final nextDeck = _StoredQuoteDeck(
      day: deck.day,
      order: order,
      cursor: cursor + 1,
      shownToday: deck.shownToday + 1,
      lastQuoteIndex: quoteIndex,
    );
    await _persist(nextDeck);

    return QuoteDeckState(
      quote: motivationQuotes[quoteIndex],
      seenToday: nextDeck.shownToday,
      total: motivationQuotes.length,
      repeatedAfterDailyPool: repeatedAfterDailyPool,
    );
  }

  Future<void> _persist(_StoredQuoteDeck deck) async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setValue(_kDay, deck.day);
    await settings.setValue(_kOrder, jsonEncode(deck.order));
    await settings.setValue(_kCursor, '${deck.cursor}');
    await settings.setValue(_kShownToday, '${deck.shownToday}');
    if (deck.lastQuoteIndex != null) {
      await settings.setValue(_kLastQuoteIndex, '${deck.lastQuoteIndex}');
    }
  }

  List<int> _shuffledIndexes({int? avoidFirst}) {
    final indexes = List<int>.generate(motivationQuotes.length, (i) => i)
      ..shuffle(_random);
    if (avoidFirst != null &&
        indexes.length > 1 &&
        indexes.first == avoidFirst) {
      final swapIndex = indexes.indexWhere((i) => i != avoidFirst);
      final temp = indexes.first;
      indexes[0] = indexes[swapIndex];
      indexes[swapIndex] = temp;
    }
    return indexes;
  }

  List<int>? _decodeOrder(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final order = decoded.map((e) => e as int).toList();
      final unique = order.toSet();
      final valid = order.length == motivationQuotes.length &&
          unique.length == motivationQuotes.length &&
          unique.every((i) => i >= 0 && i < motivationQuotes.length);
      return valid ? order : null;
    } catch (_) {
      return null;
    }
  }

  int _parseNonNegative(String? raw) {
    final parsed = int.tryParse(raw ?? '') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  int? _parseOptionalIndex(String? raw) {
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null || parsed < 0 || parsed >= motivationQuotes.length) {
      return null;
    }
    return parsed;
  }

  String _todayKey(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
