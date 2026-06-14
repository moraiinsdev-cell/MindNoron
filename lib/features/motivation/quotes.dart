import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';

part 'quote_library.g.dart';

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

/// Full motivation pool. Verified source-backed quotes are loaded first, then
/// the large raw generated library, then the small legacy inline set.
const List<Quote> motivationQuotes = <Quote>[
  ..._verifiedContentMotivationQuotes,
  ..._rawGeneratedMotivationQuotes,
  ..._legacyInlineMotivationQuotes,
];

/// Curated famous quotes replacing the original self-authored lines.
const List<Quote> _legacyInlineMotivationQuotes = <Quote>[
  // ACTION & STARTING
  Quote("The secret of getting ahead is getting started.", "Mark Twain"),
  Quote(
      "You don't have to be great to start, but you have to start to be great.",
      "Zig Ziglar"),
  Quote(
      "The best time to plant a tree was 20 years ago. The second best time is now.",
      "Chinese Proverb"),
  Quote("Act as if what you do makes a difference. It does.", "William James"),
  Quote("The way to get started is to quit talking and begin doing.",
      "Walt Disney"),
  Quote("A year from now you may wish you had started today.", "Karen Lamb"),
  Quote(
      "You don't have to see the whole staircase, just take the first step.",
      "Martin Luther King Jr."),
  Quote("The journey of a thousand miles begins with one step.", "Lao Tzu"),
  Quote("Do not wait; the time will never be just right.", "Napoleon Hill"),
  Quote("Small daily improvements over time lead to stunning results.",
      "Robin Sharma"),
  Quote("Action is the foundational key to all success.", "Pablo Picasso"),
  Quote("Just one small positive thought in the morning can change your whole day.",
      "Dalai Lama"),

  // DISCIPLINE & CONSISTENCY
  Quote(
      "We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
      "Aristotle"),
  Quote("Discipline is the bridge between goals and accomplishment.", "Jim Rohn"),
  Quote(
      "Success is nothing more than a few simple disciplines, practiced every day.",
      "Jim Rohn"),
  Quote(
      "I hated every minute of training, but I said, don't quit. Suffer now and live the rest of your life as a champion.",
      "Muhammad Ali"),
  Quote(
      "Champions aren't made in gyms. Champions are made from something they have deep inside them.",
      "Muhammad Ali"),
  Quote("There is no substitute for hard work.", "Thomas Edison"),
  Quote("The successful warrior is the average man, with laser-like focus.",
      "Bruce Lee"),
  Quote(
      "If it is important to you, you will find a way. If not, you'll find an excuse.",
      "Ryan Blair"),
  Quote("Don't count the days, make the days count.", "Muhammad Ali"),
  Quote("Work harder on yourself than you do on your job.", "Jim Rohn"),
  Quote("Motivation is what gets you started. Habit is what keeps you going.",
      "Jim Rohn"),
  Quote("You are the average of the five people you spend the most time with.",
      "Jim Rohn"),
  Quote("Push yourself, because no one else is going to do it for you.",
      "Unknown"),

  // FOCUS & ATTENTION
  Quote("That's been one of my mantras — focus and simplicity.", "Steve Jobs"),
  Quote(
      "The key is not to prioritize what's on your schedule, but to schedule your priorities.",
      "Stephen Covey"),
  Quote("Do the hard jobs first. The easy jobs will take care of themselves.",
      "Dale Carnegie"),
  Quote("You can do anything, but not everything.", "David Allen"),
  Quote(
      "It's not that I'm so smart, it's just that I stay with problems longer.",
      "Albert Einstein"),
  Quote(
      "The difference between successful people and really successful people is that really successful people say no to almost everything.",
      "Warren Buffett"),
  Quote(
      "Concentrate all your thoughts upon the work at hand. The sun's rays do not burn until brought to a focus.",
      "Alexander Graham Bell"),
  Quote("Lack of direction, not lack of time, is the problem.", "Zig Ziglar"),
  Quote("Lost time is never found again.", "Benjamin Franklin"),
  Quote("You may delay, but time will not.", "Benjamin Franklin"),
  Quote("The shorter way to do many things is to only do one thing at a time.",
      "Wolfgang Amadeus Mozart"),

  // MINDSET & BELIEF
  Quote("Whether you think you can, or you think you can't — you're right.",
      "Henry Ford"),
  Quote("Believe you can and you're halfway there.", "Theodore Roosevelt"),
  Quote("The mind is everything. What you think you become.", "Buddha"),
  Quote("Change your thoughts and you change your world.",
      "Norman Vincent Peale"),
  Quote(
      "I am not a product of my circumstances. I am a product of my decisions.",
      "Stephen Covey"),
  Quote(
      "The only limit to our realization of tomorrow will be our doubts of today.",
      "Franklin D. Roosevelt"),
  Quote("It always seems impossible until it's done.", "Nelson Mandela"),
  Quote("You are never too old to set another goal or to dream a new dream.",
      "C.S. Lewis"),
  Quote("In the middle of every difficulty lies opportunity.", "Albert Einstein"),
  Quote("Imagination is more important than knowledge.", "Albert Einstein"),
  Quote(
      "Logic will get you from A to B. Imagination will take you everywhere.",
      "Albert Einstein"),
  Quote(
      "The greatest discovery of all time is that a person can change his future by merely changing his attitude.",
      "Oprah Winfrey"),

  // RESILIENCE & ADVERSITY
  Quote(
      "Success is not final, failure is not fatal: it is the courage to continue that counts.",
      "Winston Churchill"),
  Quote("If you're going through hell, keep going.", "Winston Churchill"),
  Quote(
      "Our greatest glory is not in never falling, but in rising every time we fall.",
      "Confucius"),
  Quote("Fall seven times, stand up eight.", "Japanese Proverb"),
  Quote(
      "It does not matter how slowly you go as long as you do not stop.",
      "Confucius"),
  Quote("I have not failed. I've just found 10,000 ways that won't work.",
      "Thomas Edison"),
  Quote(
      "You have power over your mind — not outside events. Realize this, and you will find strength.",
      "Marcus Aurelius"),
  Quote(
      "The impediment to action advances action. What stands in the way becomes the way.",
      "Marcus Aurelius"),
  Quote("He who has a why to live can bear almost any how.",
      "Friedrich Nietzsche"),
  Quote("What does not kill me makes me stronger.", "Friedrich Nietzsche"),
  Quote(
      "Rock bottom became the solid foundation on which I rebuilt my life.",
      "J.K. Rowling"),
  Quote("The only way out is through.", "Robert Frost"),
  Quote(
      "When everything seems to be going against you, remember that the airplane takes off against the wind, not with it.",
      "Henry Ford"),
  Quote(
      "You may encounter many defeats, but you must not be defeated.",
      "Maya Angelou"),
  Quote(
      "We do not need magic to transform our world. We carry all the power we need inside ourselves already.",
      "J.K. Rowling"),

  // CHARACTER & IDENTITY
  Quote("Character is doing the right thing when nobody's looking.", "J.C. Watts"),
  Quote(
      "The only person you are destined to become is the person you decide to be.",
      "Ralph Waldo Emerson"),
  Quote(
      "To be yourself in a world that is constantly trying to make you something else is the greatest accomplishment.",
      "Ralph Waldo Emerson"),
  Quote("What you do speaks so loud that I cannot hear what you say.",
      "Ralph Waldo Emerson"),
  Quote(
      "What lies behind us and what lies before us are tiny matters compared to what lies within us.",
      "Ralph Waldo Emerson"),
  Quote("We are all self-made, but only the successful will admit it.",
      "Earl Nightingale"),
  Quote(
      "Waste no more time arguing about what a good man should be. Be one.",
      "Marcus Aurelius"),
  Quote("How long should you try? Until.", "Jim Rohn"),
  Quote(
      "Your life does not get better by chance, it gets better by change.",
      "Jim Rohn"),
  Quote(
      "Don't wish it were easier. Wish you were better.",
      "Jim Rohn"),

  // WORK & EXCELLENCE
  Quote(
      "Genius is one percent inspiration and ninety-nine percent perspiration.",
      "Thomas Edison"),
  Quote("The only way to do great work is to love what you do.", "Steve Jobs"),
  Quote("Quality is not an act, it is a habit.", "Aristotle"),
  Quote(
      "The difference between ordinary and extraordinary is that little extra.",
      "Jimmy Johnson"),
  Quote(
      "Impossible is just a big word thrown around by small men who find it easier to live in the world they've been given than to explore the power they have to change it.",
      "Muhammad Ali"),
  Quote("Go to bed smarter than when you woke up.", "Charlie Munger"),
  Quote(
      "Someone is sitting in the shade today because someone planted a tree a long time ago.",
      "Warren Buffett"),
  Quote("Price is what you pay. Value is what you get.", "Warren Buffett"),
  Quote("The stock market is a device for transferring money from the impatient to the patient.",
      "Warren Buffett"),
  Quote("It takes 20 years to build a reputation and five minutes to ruin it.",
      "Warren Buffett"),

  // GROWTH & LEARNING
  Quote(
      "Live as if you were to die tomorrow. Learn as if you were to live forever.",
      "Mahatma Gandhi"),
  Quote("Be the change you wish to see in the world.", "Mahatma Gandhi"),
  Quote("An investment in knowledge pays the best interest.",
      "Benjamin Franklin"),
  Quote("Anyone who stops learning is old, whether at twenty or eighty.",
      "Henry Ford"),
  Quote(
      "Education is not the filling of a pail, but the lighting of a fire.",
      "William Butler Yeats"),
  Quote(
      "Leadership and learning are indispensable to each other.",
      "John F. Kennedy"),
  Quote("Life is not about finding yourself. Life is about creating yourself.",
      "George Bernard Shaw"),
  Quote(
      "The measure of intelligence is the ability to change.",
      "Albert Einstein"),
  Quote(
      "Anyone who has never made a mistake has never tried anything new.",
      "Albert Einstein"),
  Quote(
      "The greatest glory in living lies not in never falling, but in rising every time we fall.",
      "Nelson Mandela"),

  // PURPOSE & MEANING
  Quote(
      "The future belongs to those who believe in the beauty of their dreams.",
      "Eleanor Roosevelt"),
  Quote("You must do the thing you think you cannot do.", "Eleanor Roosevelt"),
  Quote("Do what you can, with what you have, where you are.",
      "Theodore Roosevelt"),
  Quote("Keep your eyes on the stars, and your feet on the ground.",
      "Theodore Roosevelt"),
  Quote("Nothing in life is to be feared, it is only to be understood.",
      "Marie Curie"),
  Quote(
      "In the end, it's not the years in your life that count. It's the life in your years.",
      "Abraham Lincoln"),
  Quote("The best way to predict the future is to create it.", "Peter Drucker"),
  Quote("Your time is limited, so don't waste it living someone else's life.",
      "Steve Jobs"),
  Quote("Stay hungry, stay foolish.", "Steve Jobs"),
  Quote(
      "Do not go where the path may lead, go instead where there is no path and leave a trail.",
      "Ralph Waldo Emerson"),
  Quote("The purpose of life is not to be happy. It is to be useful, to be honorable, to be compassionate.",
      "Ralph Waldo Emerson"),
  Quote("Two roads diverged in a wood, and I — I took the one less traveled by.",
      "Robert Frost"),

  // CALM & STOIC CLARITY
  Quote(
      "Very little is needed to make a happy life; it is all within yourself, in your way of thinking.",
      "Marcus Aurelius"),
  Quote("The happiness of your life depends upon the quality of your thoughts.",
      "Marcus Aurelius"),
  Quote(
      "Never let the future disturb you. You will meet it, if you have to, with the same weapons of reason which today arm you against the present.",
      "Marcus Aurelius"),
  Quote(
      "If you are distressed by anything external, the pain is not due to the thing itself, but to your estimate of it.",
      "Marcus Aurelius"),
  Quote("Simplicity is the ultimate sophistication.", "Leonardo da Vinci"),
  Quote("The noblest pleasure is the joy of understanding.",
      "Leonardo da Vinci"),
  Quote(
      "I am always doing that which I cannot do, in order that I may learn how to do it.",
      "Pablo Picasso"),
  Quote(
      "Everything you've ever wanted is on the other side of fear.",
      "George Addair"),
  Quote(
      "Twenty years from now you will be more disappointed by the things that you didn't do than by the ones you did do.",
      "Mark Twain"),
  Quote("The only source of knowledge is experience.", "Albert Einstein"),
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
