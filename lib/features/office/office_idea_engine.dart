import 'dart:convert';
import 'dart:math';

/// What kind of idea an idea-room produces. Each maps to a themed room and a
/// distinct generation blueprint.
enum IdeaCategory { product, marketing, mindnoron, fromWork }

extension IdeaCategoryX on IdeaCategory {
  /// Short Vietnamese label for the UI.
  String get label => switch (this) {
        IdeaCategory.product => 'Sản phẩm',
        IdeaCategory.marketing => 'Marketing',
        IdeaCategory.mindnoron => 'MindNoron',
        IdeaCategory.fromWork => 'Việc của tôi',
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
/// any network/LLM — it composes curated Vietnamese word-banks with coherent
/// templates so each idea reads like a concrete, developable concept rather
/// than random filler, and personalises [IdeaCategory.fromWork] with the
/// player's real task/note titles.
class IdeaEngine {
  IdeaEngine([Random? rng]) : _rng = rng ?? Random();

  final Random _rng;
  int _seq = 0;

  // --- shared banks --------------------------------------------------------

  static const _audiences = [
    'freelancer', 'sinh viên', 'chủ shop online nhỏ', 'nhà sáng tạo nội dung',
    'đội ngũ làm việc từ xa', 'người mới tập gym', 'phụ huynh bận rộn',
    'lập trình viên indie', 'người học ngoại ngữ', 'nhà đầu tư cá nhân F0',
    'quản lý dự án', 'chủ quán cà phê', 'người theo lối sống tối giản',
    'người sáng tạo bán khoá học',
  ];

  static const _pains = [
    'mất quá nhiều thời gian làm thủ công',
    'khó giữ thói quen đều đặn',
    'thông tin nằm rải rác nhiều nơi',
    'khó ra quyết định nhanh',
    'dễ mất động lực giữa chừng',
    'khó theo dõi tiến độ thực tế',
    'công cụ hiện có quá đắt hoặc quá rườm rà',
    'quá tải thông báo và việc vặt',
    'khó cộng tác khi mỗi người một nơi',
  ];

  static const _formats = [
    'một app desktop gọn nhẹ',
    'một tiện ích chạy nền tự động',
    'một bản tin (newsletter) cá nhân hoá',
    'một bảng điều khiển trực quan',
    'một bộ mẫu (template) bán sẵn',
    'một trợ lý nhắc việc thông minh',
    'một công cụ "một-cú-click"',
    'một cộng đồng có cấu trúc rõ ràng',
    'một trò chơi hoá thói quen',
  ];

  static const _angles = [
    'ưu tiên offline & quyền riêng tư',
    'cá nhân hoá theo chính dữ liệu của bạn',
    'gamification để giữ động lực',
    'tự động hoá phần việc lặp lại',
    'micro-SaaS giá rẻ, trả-một-lần',
    'tích hợp lịch & nhắc nhở thông minh',
    'thiết kế tối giản, không gây xao nhãng',
    'chia sẻ tiến độ với cộng đồng để có trách nhiệm',
  ];

  static const _channels = [
    'video ngắn TikTok/Reels',
    'SEO theo từ khoá ngách',
    'cộng đồng Discord/Zalo',
    'Product Hunt & Reddit',
    'hợp tác micro-influencer',
    'chương trình giới thiệu (referral)',
    'email nuôi dưỡng khách',
    'build-in-public trên X/Threads',
    'hội nhóm Facebook chuyên ngành',
  ];

  static const _validations = [
    'làm landing page thu email trong 1 ngày',
    'phỏng vấn 5 người dùng mục tiêu',
    'dựng bản mẫu bấm-được bằng no-code',
    'bán trước 10 suất early-bird',
    'đăng demo xin phản hồi từ cộng đồng',
  ];

  // --- marketing banks -----------------------------------------------------

  static const _tactics = [
    'chuỗi nội dung "trước / sau"',
    'thử thách 7 ngày có check-in',
    'giveaway yêu cầu chia sẻ',
    'case study người dùng thật',
    'so sánh thẳng thắn với đối thủ',
    'nhật ký build-in-public',
    'mini-tool miễn phí làm mồi',
    'chương trình đại sứ thương hiệu',
    'series livestream hỏi-đáp',
    'ưu đãi early-bird giới hạn số lượng',
  ];

  static const _hooks = [
    'nhấn vào một nỗi đau rất cụ thể',
    'khoe kết quả đo lường được',
    'kể câu chuyện chuyển đổi của một người',
    'tạo cảm giác khan hiếm có thật',
    'mời tham gia thay vì rao bán',
  ];

  static const _metrics = [
    'tỉ lệ đăng ký email',
    'tỉ lệ dùng thử → trả phí',
    'chi phí có một khách (CAC)',
    'tỉ lệ giữ chân tuần đầu',
    'lượt chia sẻ tự nhiên',
  ];

  // --- MindNoron banks -----------------------------------------------------

  static const _modules = [
    'Tasks', 'Lịch', 'Tài chính', 'Pomodoro / Focus', 'Ghi chú', 'Thói quen',
    'Inbox', 'Nhật ký', 'Văn phòng ảo', 'Chi tiêu', 'Dashboard',
  ];

  static const _improvements = [
    'thêm chế độ xem theo tuần',
    'tự động gợi ý thứ tự ưu tiên',
    'biểu đồ xu hướng theo thời gian',
    'bộ mẫu nhanh để tạo trong 1 chạm',
    'nhắc nhở thông minh dựa trên thói quen',
    'liên kết chéo giữa các module',
    'báo cáo tổng kết tự động cuối tuần',
    'chế độ tập trung sâu, ẩn mọi thứ khác',
    'thưởng xu khi hoàn thành để tạo động lực',
    'một widget mini luôn hiển thị trên màn hình',
  ];

  static const _benefits = [
    'tiết kiệm thời gian thao tác',
    'giữ động lực lâu hơn',
    'ra quyết định nhanh hơn',
    'giảm xao nhãng',
    'nhìn bức tranh tổng thể rõ hơn',
  ];

  // --- fromWork banks ------------------------------------------------------

  static const _workAngles = [
    'chia nhỏ thành 3 bước làm được ngay',
    'biến thành một thói quen lặp lại hằng tuần',
    'ghi lại bài học ngay sau khi xong',
    'tìm cách tự động hoá phần lặp đi lặp lại',
    'đặt một mốc thời gian kèm phần thưởng',
    'rủ một người cùng làm để có trách nhiệm',
    'viết lại thành ghi chú có thể chia sẻ',
    'chọn một con số duy nhất để đo kết quả',
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
    final title = '${_capitalize(format)} cho $audience — $angle';
    final pitch = _block({
      'Vấn đề': '$audience đang $pain.',
      'Đối tượng': audience,
      'Giải pháp': '$format giúp họ giải quyết điều đó',
      'Điểm khác biệt': angle,
      'Kênh tiếp cận': channel,
      'Bước tiếp theo': next,
    });
    return (title, pitch, _score(base: 64, bonus: 12));
  }

  (String, String, int) _marketing() {
    final tactic = _pick(_tactics);
    final audience = _pick(_audiences);
    final channel = _pick(_channels);
    final hook = _pick(_hooks);
    final metric = _pick(_metrics);
    final title = '${_capitalize(tactic)} trên $channel cho $audience';
    final pitch = _block({
      'Chiến thuật': tactic,
      'Đối tượng': audience,
      'Kênh': channel,
      'Thông điệp': 'Hãy $hook.',
      'Đo bằng': metric,
      'Làm ngay': 'Lên 5 nội dung mẫu và đăng thử trong tuần này.',
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
      'Đề xuất': _capitalize(improvement),
      'Lợi ích': 'Giúp người dùng $benefit.',
      'Độ ưu tiên': _pick(const ['Cao', 'Trung bình', 'Thử nghiệm']),
      'Bước tiếp theo': 'Phác thảo nhanh giao diện rồi làm bản thử nhỏ.',
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
    final title = 'Từ "$short": ${_capitalize(angle)}';
    final pitch = _block({
      'Dựa trên': seed,
      'Gợi ý': _capitalize(angle),
      'Vì sao': 'Biến việc đang dở dang thành bước đi cụ thể, đo được.',
      'Làm ngay': 'Dành 15 phút phác thảo và đặt hạn cho bước đầu tiên.',
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
