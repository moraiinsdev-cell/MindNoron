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

  /// Multi-line structured pitch.
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

/// A coherent, fully-offline idea generator (no network/LLM).
///
/// Earlier versions slot-filled random word-banks, which produced incoherent
/// combinations ("a pool app for café owners"). This version instead draws from
/// a **curated library of complete, hand-written ideas** — each one already
/// makes sense — and personalises [IdeaCategory.fromWork] by wrapping the
/// player's real task/note titles in a sensible next action.
class IdeaEngine {
  IdeaEngine([Random? rng]) : _rng = rng ?? Random();

  final Random _rng;
  int _seq = 0;

  // Each entry is a complete, coherent idea: (one-line hook, structured pitch).
  // Pitches are written so the parts fit together rather than being random.

  static const _products = <(String, String)>[
    (
      'Receipt → expense log for small online shops',
      '• Problem: owners lose hours typing receipts into a spreadsheet.\n'
          '• Who: small online-shop owners who do their own books.\n'
          '• Solution: snap a receipt; it reads amount/date/vendor and appends a row.\n'
          '• Edge: works offline and exports to the sheet they already use.\n'
          '• First step: mock the capture → row flow with 10 real receipts.'
    ),
    (
      'Focus-streak tracker for remote workers',
      '• Problem: deep work slips without anything keeping you honest.\n'
          '• Who: remote workers who set their own hours.\n'
          '• Solution: a desktop widget that counts consecutive deep-work days.\n'
          '• Edge: gamified streaks, fully local, no account needed.\n'
          '• First step: ship the streak counter + a "don\'t break the chain" view.'
    ),
    (
      'Flashcards generated from your own notes',
      '• Problem: language learners re-type notes into a flashcard app by hand.\n'
          '• Who: self-studying language learners.\n'
          '• Solution: point it at your notes; it turns highlighted lines into cards.\n'
          '• Edge: spaced-repetition that uses material you actually wrote.\n'
          '• First step: parse one notes file into a deck and test recall.'
    ),
    (
      'Weekly meal planner with an auto grocery list',
      '• Problem: deciding dinner nightly is exhausting and wasteful.\n'
          '• Who: busy parents cooking for a household.\n'
          '• Solution: pick a week of meals; it rolls up one de-duplicated shopping list.\n'
          '• Edge: reuse favourite weeks in one tap.\n'
          '• First step: build the meal → ingredients → merged list pipeline.'
    ),
    (
      'Invoice follow-up reminder for freelancers',
      '• Problem: unpaid invoices get forgotten, hurting cash flow.\n'
          '• Who: freelancers juggling several clients.\n'
          '• Solution: log an invoice + due date; it nudges you to chase overdue ones.\n'
          '• Edge: drafts a polite follow-up you can send in one click.\n'
          '• First step: a list of invoices with a "days overdue" badge.'
    ),
    (
      'Subscription auditor that flags what you never use',
      '• Problem: money leaks on subscriptions you forgot about.\n'
          '• Who: anyone with a stack of monthly services.\n'
          '• Solution: list your subscriptions; it surfaces the ones you haven\'t opened.\n'
          '• Edge: a clear "cancel candidates" view with the yearly cost.\n'
          '• First step: manual entry + a sortable cost/usage table.'
    ),
    (
      'Stand-up summariser for small remote teams',
      '• Problem: written stand-ups scatter across chat and get lost.\n'
          '• Who: remote teams of 3–8 people.\n'
          '• Solution: each person drops 3 lines; it compiles a single daily digest.\n'
          '• Edge: a weekly rollup that shows what actually shipped.\n'
          '• First step: a form → daily digest, no integrations yet.'
    ),
    (
      'Reading-queue triage for knowledge workers',
      '• Problem: a bottomless "read later" pile you never get through.\n'
          '• Who: people who save far more than they read.\n'
          '• Solution: it serves one item at a time and asks read / skip / archive.\n'
          '• Edge: estimates time-to-clear so the queue feels finite.\n'
          '• First step: import a list and build the one-at-a-time triage screen.'
    ),
    (
      'Progressive-overload workout logger for beginners',
      '• Problem: beginners plateau because they don\'t track weight × reps.\n'
          '• Who: people new to the gym.\n'
          '• Solution: log each set; it suggests the next session\'s targets.\n'
          '• Edge: dead-simple input and a clear "you\'re getting stronger" chart.\n'
          '• First step: log → next-target suggestion for one lift.'
    ),
    (
      'Personal CRM for solo creators',
      '• Problem: collabs and contacts live in scattered DMs.\n'
          '• Who: solo creators managing partnerships.\n'
          '• Solution: a lightweight contact list with last-touch + follow-up dates.\n'
          '• Edge: reminders to reconnect before a relationship goes cold.\n'
          '• First step: contacts + "reach out again on" date.'
    ),
    (
      'Pomodoro timer with a built-in site blocker',
      '• Problem: focus timers don\'t stop you opening distracting sites.\n'
          '• Who: students and focus-seekers.\n'
          '• Solution: starting a session blocks a chosen list until the timer ends.\n'
          '• Edge: one toggle, no accounts, all local.\n'
          '• First step: timer + a blocklist that activates during a session.'
    ),
    (
      'Price-drop watcher for a small wishlist',
      '• Problem: people overpay by buying before a sale.\n'
          '• Who: deliberate shoppers with a short wishlist.\n'
          '• Solution: add a product + target price; it alerts when it drops.\n'
          '• Edge: a calm, no-FOMO list instead of constant deal spam.\n'
          '• First step: manual price entry + a "below target" alert.'
    ),
    (
      'Cold-email follow-up scheduler for indie founders',
      '• Problem: one email rarely lands; founders forget to follow up.\n'
          '• Who: indie founders doing their own outreach.\n'
          '• Solution: queue an email with a 2-step follow-up cadence.\n'
          '• Edge: stops chasing once someone replies.\n'
          '• First step: a sequence editor + a "due to follow up" list.'
    ),
    (
      'End-of-day shutdown ritual app',
      '• Problem: work bleeds into the evening with no clean stop.\n'
          '• Who: people who struggle to switch off.\n'
          '• Solution: a 3-minute checklist (tomorrow\'s top task, inbox to zero, close tabs).\n'
          '• Edge: a satisfying "day closed" moment that protects rest.\n'
          '• First step: a customisable checklist + a daily completion streak.'
    ),
  ];

  static const _marketing = <(String, String)>[
    (
      'Build-in-public weekly devlog',
      '• Goal: build an audience while you build the product.\n'
          '• Do: post one screenshot + one lesson every week on X/Threads.\n'
          '• Why it works: progress is relatable and compounding.\n'
          '• Measure: followers and replies per post.\n'
          '• Start: schedule the first 4 posts now.'
    ),
    (
      '7-day challenge with daily check-ins',
      '• Goal: drive trials and habit formation at once.\n'
          '• Do: invite people to a themed 7-day challenge; they check in daily.\n'
          '• Why it works: streaks create commitment and word of mouth.\n'
          '• Measure: day-7 completion rate.\n'
          '• Start: write the 7 prompts and a sign-up page.'
    ),
    (
      'Free mini-tool as a lead magnet',
      '• Goal: attract your exact audience with something instantly useful.\n'
          '• Do: ship a tiny single-purpose free tool that hints at the paid product.\n'
          '• Why it works: utility earns the email far better than a popup.\n'
          '• Measure: tool users → email sign-ups.\n'
          '• Start: pick the one calculation/utility users would bookmark.'
    ),
    (
      'Before / after transformation series',
      '• Goal: make the value concrete and shareable.\n'
          '• Do: post real "messy before → clean after" cases using the product.\n'
          '• Why it works: visible outcomes beat feature lists.\n'
          '• Measure: shares and saves.\n'
          '• Start: collect 3 before/after pairs from real use.'
    ),
    (
      'Honest competitor comparison post',
      '• Goal: capture buyers already comparing options.\n'
          '• Do: a fair "X vs us — when to pick which" article.\n'
          '• Why it works: candour builds trust and ranks for high-intent search.\n'
          '• Measure: organic visits → trials.\n'
          '• Start: outline the 5 dimensions that actually matter.'
    ),
    (
      'Founder story: why I built this',
      '• Goal: give the product a memorable origin.\n'
          '• Do: tell the specific personal frustration that started it.\n'
          '• Why it works: people back people and stories, not features.\n'
          '• Measure: comments and reshares.\n'
          '• Start: draft the 300-word version of your story.'
    ),
    (
      'Referral: give a month, get a month',
      '• Goal: turn happy users into a growth loop.\n'
          '• Do: both referrer and friend get a free month.\n'
          '• Why it works: aligned incentives + social proof.\n'
          '• Measure: invites sent → activated.\n'
          '• Start: add a shareable referral link to the app.'
    ),
    (
      'Value-first answers in niche communities',
      '• Goal: reach buyers where they already ask for help.\n'
          '• Do: genuinely answer questions in 2–3 relevant forums/subreddits; mention the product only when it truly fits.\n'
          '• Why it works: trust first, link second.\n'
          '• Measure: profile clicks → trials.\n'
          '• Start: find 10 recent threads you can actually help with.'
    ),
    (
      '5-email onboarding sequence',
      '• Goal: turn sign-ups into active users.\n'
          '• Do: 5 short emails, each teaching one quick win.\n'
          '• Why it works: guided first wins drive activation and retention.\n'
          '• Measure: trial → paid conversion.\n'
          '• Start: list the 5 "aha" moments and write email #1.'
    ),
    (
      'Limited early-bird with a real cap',
      '• Goal: reward early supporters and create momentum.\n'
          '• Do: offer the first 50 a lifetime/discount deal — and honour the cap.\n'
          '• Why it works: genuine scarcity, not fake countdowns.\n'
          '• Measure: spots claimed.\n'
          '• Start: pick the cap and the offer, then announce.'
    ),
    (
      'User case study with real numbers',
      '• Goal: prove the product moves a metric.\n'
          '• Do: interview one power user; publish their concrete results.\n'
          '• Why it works: a credible number persuades the next buyer.\n'
          '• Measure: case-study page → trials.\n'
          '• Start: ask your most active user for 15 minutes.'
    ),
    (
      '15-second demo clips of single wins',
      '• Goal: show value fast on short-form video.\n'
          '• Do: one clip = one tiny "watch this get easier" moment.\n'
          '• Why it works: bite-size utility is highly shareable.\n'
          '• Measure: views → profile visits.\n'
          '• Start: record 3 clips of the product\'s best small moments.'
    ),
  ];

  static const _mindnoron = <(String, String)>[
    (
      'Weekly review screen',
      '• What: a Sunday view that auto-summarises the week — tasks done, habits kept, focus hours.\n'
          '• Why: turns scattered activity into a sense of progress.\n'
          '• Where: a new tab pulling from Tasks, Habits and Pomodoro.\n'
          '• Effort: medium — mostly aggregation of data you already store.'
    ),
    (
      'Link notes to tasks',
      '• What: attach notes to a task; opening the task shows them inline.\n'
          '• Why: stops context from living in two disconnected places.\n'
          '• Where: a relation between Tasks and Notes + an inline panel.\n'
          '• Effort: medium.'
    ),
    (
      'Natural-language quick capture',
      '• What: type "pay rent friday 5pm" and it creates the task with date/time.\n'
          '• Why: capture should be one line, not a form.\n'
          '• Where: the capture dialog + a small date parser.\n'
          '• Effort: medium — start with dates, expand later.'
    ),
    (
      'Always-on-top "Today" widget',
      '• What: a tiny floating window with today\'s top 3 tasks + the timer.\n'
          '• Why: keeps focus visible without opening the full app.\n'
          '• Where: a compact window using the existing task/timer data.\n'
          '• Effort: medium (window_manager already in the app).'
    ),
    (
      'Habit heatmap on the dashboard',
      '• What: a GitHub-style grid of habit completions over time.\n'
          '• Why: streaks are motivating when you can see them.\n'
          '• Where: Dashboard, fed by Habit completions.\n'
          '• Effort: small–medium.'
    ),
    (
      'Pomodoro auto-logs to the chosen task',
      '• What: pick a task before a focus session; minutes log against it.\n'
          '• Why: real "time spent per task" without manual tracking.\n'
          '• Where: Timer ↔ Tasks link + a per-task time total.\n'
          '• Effort: small–medium.'
    ),
    (
      'Recurring tasks & templates',
      '• What: tasks that repeat (daily/weekly) and reusable task templates.\n'
          '• Why: stop re-typing the same routine work.\n'
          '• Where: Tasks — a recurrence rule + a template picker.\n'
          '• Effort: medium.'
    ),
    (
      'Expense trends + monthly cap alerts',
      '• What: a spending-over-time chart and a nudge when you near a category cap.\n'
          '• Why: awareness before the month is blown, not after.\n'
          '• Where: Expenses + a simple budget per category.\n'
          '• Effort: medium.'
    ),
    (
      'Unified day view: calendar + tasks together',
      '• What: one timeline showing events and due/scheduled tasks side by side.\n'
          '• Why: plan the day in one place instead of switching tabs.\n'
          '• Where: a new view over Calendar + Tasks.\n'
          '• Effort: medium.'
    ),
    (
      'Deep focus mode that hides everything else',
      '• What: a full-screen mode showing only the current task + timer.\n'
          '• Why: remove every on-screen temptation during a sprint.\n'
          '• Where: a mode toggle reusing the timer + selected task.\n'
          '• Effort: small.'
    ),
    (
      'End-of-day journal prompt from today\'s wins',
      '• What: at day\'s end, pre-fill the journal with what you completed.\n'
          '• Why: reflection is easier when the facts are already there.\n'
          '• Where: Journal seeded from today\'s done tasks.\n'
          '• Effort: small.'
    ),
    (
      'One-keystroke inbox triage',
      '• What: on an inbox item, press one key to send it to task / note / calendar.\n'
          '• Why: clear the inbox fast without dialogs.\n'
          '• Where: Inbox + keyboard shortcuts.\n'
          '• Effort: small–medium.'
    ),
    (
      'Streak-based coin rewards (office tie-in)',
      '• What: keep a streak and the virtual office pays bonus coins.\n'
          '• Why: connects real consistency to the office reward loop.\n'
          '• Where: Habits/streaks → office economy.\n'
          '• Effort: small.'
    ),
  ];

  /// Coherent next-action frames for the player's real tasks/notes. Each wraps
  /// the real title in a sensible move, so the result always makes sense.
  static const _workFrames = <(String, String)>[
    ('Break it down',
        'Split it into 3 concrete sub-steps and do the first one in the next 25 minutes.'),
    ('Time-box it',
        'Start a 25-minute focus session on it right now; stop cleanly when the timer ends.'),
    ('Define "done"',
        'Write one sentence describing what finished looks like, then work backwards from it.'),
    ('Find the blocker',
        'Name the single thing holding it up and clear that before anything else.'),
    ('Make it routine',
        'If this keeps coming back, schedule it as a weekly recurring task so it stops piling up.'),
    ('Capture the lesson',
        'After it\'s done, jot two lines on what worked so next time is faster.'),
    ('Delegate or drop',
        'Decide: can it be handed off or cut? If not, give it a real deadline today.'),
    ('Make it visible',
        'Pin it as today\'s top task so it doesn\'t get buried under smaller things.'),
  ];

  T _pick<T>(List<T> xs) => xs[_rng.nextInt(xs.length)];

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_seq++}-${_rng.nextInt(9999)}';

  /// Generates a batch of [count] ideas, avoiding titles already in
  /// [recentTitles] and within the batch.
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
        if (c != IdeaCategory.fromWork ||
            taskTitles.isNotEmpty ||
            noteTitles.isNotEmpty)
          c,
    ];
    if (cats.isEmpty) return const [];

    final out = <GeneratedIdea>[];
    final seen = {...recentTitles};
    var guard = 0;
    while (out.length < count && guard < count * 14) {
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
      IdeaCategory.product => _curated(_products, 72),
      IdeaCategory.marketing => _curated(_marketing, 70),
      IdeaCategory.mindnoron => _curated(_mindnoron, 74),
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

  (String, String, int) _curated(List<(String, String)> bank, int base) {
    final (title, pitch) = _pick(bank);
    // Stable-ish score per idea + a little jitter.
    final score = (base + (title.hashCode.abs() % 16) + _rng.nextInt(6))
        .clamp(40, 96);
    return (title, pitch, score);
  }

  (String, String, int) _fromWork(
      List<String> taskTitles, List<String> noteTitles) {
    final pool = [...taskTitles, ...noteTitles]
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (pool.isEmpty) {
      return _curated(_products, 72); // nothing personal to use yet
    }
    final seed = pool[_rng.nextInt(pool.length)];
    final (frameTitle, frameBody) = _pick(_workFrames);
    final short = seed.length > 44 ? '${seed.substring(0, 44)}…' : seed;
    final title = '$frameTitle: "$short"';
    final pitch = '• Your item: $seed\n'
        '• Move: $frameBody\n'
        '• Why: turns something on your list into a concrete next action.';
    // Personalised ideas are the most actionable → score them a touch higher.
    return (title, pitch, (80 + _rng.nextInt(13)).clamp(40, 96));
  }
}
