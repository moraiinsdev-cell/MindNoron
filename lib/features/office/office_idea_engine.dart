import 'dart:convert';
import 'dart:math';

/// What kind of idea an idea-room produces. Each maps to a themed room and a
/// distinct generation blueprint.
enum IdeaCategory { product, marketing, mindnoron, fromWork }

extension IdeaCategoryX on IdeaCategory {
  /// Short label for the UI.
  String get label => switch (this) {
        IdeaCategory.product => 'Product',
        IdeaCategory.marketing => 'Marketing',
        IdeaCategory.mindnoron => 'MindNoron',
        IdeaCategory.fromWork => 'My work',
      };

  String get emoji => switch (this) {
        IdeaCategory.product => '🚀',
        IdeaCategory.marketing => '📣',
        IdeaCategory.mindnoron => '🧠',
        IdeaCategory.fromWork => '📌',
      };

  /// The idea-room (map label) that produces this category.
  String get room => switch (this) {
        IdeaCategory.product => 'R&D',
        IdeaCategory.marketing => 'MARKETING',
        IdeaCategory.mindnoron => 'BRAINSTORM',
        IdeaCategory.fromWork => 'PITCH',
      };

  static IdeaCategory? fromName(String name) {
    for (final c in IdeaCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// One generated idea: a one-line hook plus a structured pitch, scored for
/// "developability" and persisted so the player can review it later.
class GeneratedIdea {
  GeneratedIdea({
    required this.id,
    required this.category,
    required this.title,
    required this.pitch,
    required this.score,
    required this.createdAt,
    this.starred = false,
    this.dismissed = false,
  });

  final String id;
  final IdeaCategory category;

  /// One-line hook shown in the list.
  final String title;

  /// Multi-line structured pitch (problem → audience → solution → …).
  final String pitch;

  /// 0..100 estimate of how concrete / developable the idea is.
  final int score;
  final DateTime createdAt;
  final bool starred;
  final bool dismissed;

  GeneratedIdea copyWith({bool? starred, bool? dismissed}) => GeneratedIdea(
        id: id,
        category: category,
        title: title,
        pitch: pitch,
        score: score,
        createdAt: createdAt,
        starred: starred ?? this.starred,
        dismissed: dismissed ?? this.dismissed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cat': category.name,
        'title': title,
        'pitch': pitch,
        'score': score,
        'at': createdAt.toIso8601String(),
        'star': starred,
        'gone': dismissed,
      };

  static GeneratedIdea? fromJson(Map<String, dynamic> j) {
    final cat = IdeaCategoryX.fromName(j['cat'] as String? ?? '');
    final title = j['title'] as String?;
    if (cat == null || title == null) return null;
    return GeneratedIdea(
      id: j['id'] as String? ?? title.hashCode.toString(),
      category: cat,
      title: title,
      pitch: j['pitch'] as String? ?? '',
      score: (j['score'] as num?)?.toInt() ?? 60,
      createdAt:
          DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      starred: j['star'] as bool? ?? false,
      dismissed: j['gone'] as bool? ?? false,
    );
  }

  static String encodeList(List<GeneratedIdea> ideas) =>
      jsonEncode([for (final i in ideas) i.toJson()]);

  static List<GeneratedIdea> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            if (GeneratedIdea.fromJson(e) case final idea?) idea,
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// A purely offline, deterministic-per-seed idea generator. It does NOT call
/// any network/LLM — it composes curated word-banks with coherent templates so
/// each idea reads like a concrete, developable concept rather than random
/// filler, and personalises [IdeaCategory.fromWork] with the player's real
/// task/note titles.
class IdeaEngine {
  IdeaEngine([Random? rng]) : _rng = rng ?? Random();

  final Random _rng;
  int _seq = 0;

  // --- shared banks --------------------------------------------------------

  static const _audiences = [
    'freelancers', 'students', 'small online-shop owners', 'content creators',
    'remote teams', 'gym beginners', 'busy parents', 'indie developers',
    'language learners', 'first-time retail investors', 'project managers',
    'café owners', 'minimalists', 'course creators',
  ];

  static const _pains = [
    'waste too much time on manual work',
    'struggle to keep habits consistent',
    'have information scattered across many places',
    'find it hard to decide quickly',
    'lose motivation halfway through',
    'can\'t track real progress',
    'find existing tools too expensive or bloated',
    'are overloaded with notifications and busywork',
    'find it hard to collaborate when apart',
  ];

  static const _formats = [
    'a lightweight desktop app',
    'a background utility that runs automatically',
    'a personalised newsletter',
    'a clean visual dashboard',
    'a pack of ready-made templates',
    'a smart reminder assistant',
    'a one-click tool',
    'a well-structured community',
    'a habit-gamifying app',
  ];

  static const _angles = [
    'offline-first & privacy-respecting',
    'personalised from your own data',
    'gamified to keep motivation up',
    'automates the repetitive parts',
    'a cheap, pay-once micro-SaaS',
    'smart calendar & reminder integration',
    'minimal, distraction-free design',
    'shares progress with a community for accountability',
  ];

  static const _channels = [
    'short-form video (TikTok/Reels)',
    'niche-keyword SEO',
    'a Discord/community server',
    'Product Hunt & Reddit',
    'micro-influencer partnerships',
    'a referral program',
    'an email nurture sequence',
    'build-in-public on X/Threads',
    'specialised Facebook groups',
  ];

  static const _validations = [
    'ship a landing page to collect emails in a day',
    'interview 5 target users',
    'build a clickable no-code prototype',
    'pre-sell 10 early-bird spots',
    'post a demo and ask the community for feedback',
  ];

  // --- marketing banks -----------------------------------------------------

  static const _tactics = [
    'a "before / after" content series',
    'a 7-day challenge with daily check-ins',
    'a giveaway that rewards sharing',
    'a real user case study',
    'an honest head-to-head with a competitor',
    'a build-in-public devlog',
    'a free mini-tool as a lead magnet',
    'a brand-ambassador program',
    'a live Q&A series',
    'a limited early-bird offer',
  ];

  static const _hooks = [
    'lead with one very specific pain point',
    'show a measurable result',
    'tell one person\'s transformation story',
    'create genuine scarcity',
    'invite people in instead of selling at them',
  ];

  static const _metrics = [
    'email sign-up rate',
    'trial → paid conversion',
    'cost per acquired customer (CAC)',
    'week-one retention',
    'organic shares',
  ];

  // --- MindNoron banks -----------------------------------------------------

  static const _modules = [
    'Tasks', 'Calendar', 'Finance', 'Pomodoro / Focus', 'Notes', 'Habits',
    'Inbox', 'Journal', 'Virtual office', 'Expenses', 'Dashboard',
  ];

  static const _improvements = [
    'add a weekly view',
    'auto-suggest a priority order',
    'a trend chart over time',
    'quick templates to create in one tap',
    'smart reminders based on habits',
    'cross-links between modules',
    'an automatic weekend recap',
    'a deeper focus mode that hides everything else',
    'reward coins on completion to build momentum',
    'a mini widget that\'s always on screen',
  ];

  static const _benefits = [
    'save time on busywork',
    'stay motivated longer',
    'decide faster',
    'cut distractions',
    'see the big picture more clearly',
  ];

  // --- fromWork banks ------------------------------------------------------

  static const _workAngles = [
    'break it into 3 steps you can do right now',
    'turn it into a weekly recurring habit',
    'capture the lesson right after you finish',
    'find a way to automate the repetitive part',
    'set a deadline with a reward attached',
    'pull in a partner so you stay accountable',
    'rewrite it as a shareable note',
    'pick a single number to measure the result',
  ];

  T _pick<T>(List<T> xs) => xs[_rng.nextInt(xs.length)];

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_seq++}-${_rng.nextInt(9999)}';

  /// Generates a batch of [count] ideas, avoiding titles already in
  /// [recentTitles] and within the batch. [categories] limits which kinds of
  /// idea are produced (defaults to all four). [taskTitles]/[noteTitles] feed
  /// the personalised "from my work" blueprint.
  List<GeneratedIdea> generateBatch(
    int count, {
    Set<String> recentTitles = const {},
    List<IdeaCategory> categories = IdeaCategory.values,
    List<String> taskTitles = const [],
    List<String> noteTitles = const [],
  }) {
    if (categories.isEmpty) return const [];
    final cats = [
      for (final c in categories)
        // Drop fromWork if there's nothing personal to seed it with.
        if (c != IdeaCategory.fromWork ||
            taskTitles.isNotEmpty ||
            noteTitles.isNotEmpty)
          c,
    ];
    if (cats.isEmpty) return const [];

    final out = <GeneratedIdea>[];
    final seen = {...recentTitles};
    var guard = 0;
    while (out.length < count && guard < count * 12) {
      guard++;
      final idea = generate(
        cats[_rng.nextInt(cats.length)],
        taskTitles: taskTitles,
        noteTitles: noteTitles,
      );
      if (seen.contains(idea.title)) continue;
      seen.add(idea.title);
      out.add(idea);
    }
    return out;
  }

  /// Generates a single idea for [category].
  GeneratedIdea generate(
    IdeaCategory category, {
    List<String> taskTitles = const [],
    List<String> noteTitles = const [],
  }) {
    final (title, pitch, score) = switch (category) {
      IdeaCategory.product => _product(),
      IdeaCategory.marketing => _marketing(),
      IdeaCategory.mindnoron => _mindnoron(),
      IdeaCategory.fromWork => _fromWork(taskTitles, noteTitles),
    };
    return GeneratedIdea(
      id: _newId(),
      category: category,
      title: title,
      pitch: pitch,
      score: score,
      createdAt: DateTime.now(),
    );
  }

  (String, String, int) _product() {
    final audience = _pick(_audiences);
    final pain = _pick(_pains);
    final format = _pick(_formats);
    final angle = _pick(_angles);
    final channel = _pick(_channels);
    final next = _pick(_validations);
    final title = '${_capitalize(format)} for $audience — $angle';
    final pitch = _block({
      'Problem': '$audience $pain.',
      'Audience': audience,
      'Solution': '$format that solves exactly that',
      'Edge': angle,
      'Channel': channel,
      'Next step': next,
    });
    return (title, pitch, _score(base: 64, bonus: 12));
  }

  (String, String, int) _marketing() {
    final tactic = _pick(_tactics);
    final audience = _pick(_audiences);
    final channel = _pick(_channels);
    final hook = _pick(_hooks);
    final metric = _pick(_metrics);
    final title = '${_capitalize(tactic)} on $channel for $audience';
    final pitch = _block({
      'Tactic': tactic,
      'Audience': audience,
      'Channel': channel,
      'Message': 'Lead by: $hook.',
      'Measure with': metric,
      'Do now': 'Draft 5 sample posts and ship a test this week.',
    });
    return (title, pitch, _score(base: 60, bonus: 14));
  }

  (String, String, int) _mindnoron() {
    final module = _pick(_modules);
    final improvement = _pick(_improvements);
    final benefit = _pick(_benefits);
    final title = 'MindNoron · $module: ${_capitalize(improvement)}';
    final pitch = _block({
      'Module': module,
      'Proposal': _capitalize(improvement),
      'Benefit': 'Helps users $benefit.',
      'Priority': _pick(const ['High', 'Medium', 'Experiment']),
      'Next step': 'Sketch the UI quickly, then build a small spike.',
    });
    return (title, pitch, _score(base: 58, bonus: 16));
  }

  (String, String, int) _fromWork(
      List<String> taskTitles, List<String> noteTitles) {
    final pool = [...taskTitles, ...noteTitles]
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (pool.isEmpty) {
      // Fall back to a product idea if there's nothing personal to use.
      return _product();
    }
    final seed = _pick(pool);
    final angle = _pick(_workAngles);
    final short = seed.length > 42 ? '${seed.substring(0, 42)}…' : seed;
    final title = 'From "$short": ${_capitalize(angle)}';
    final pitch = _block({
      'Based on': seed,
      'Suggestion': _capitalize(angle),
      'Why': 'Turns a half-finished task into a concrete, measurable step.',
      'Do now': 'Spend 15 minutes sketching it and set a deadline for step 1.',
    });
    // Personalised ideas are the most actionable → score them higher.
    return (title, pitch, _score(base: 72, bonus: 12));
  }

  String _block(Map<String, String> rows) => [
        for (final e in rows.entries) '• ${e.key}: ${e.value}',
      ].join('\n');

  int _score({required int base, required int bonus}) =>
      (base + _rng.nextInt(bonus + 1)).clamp(40, 97);

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
