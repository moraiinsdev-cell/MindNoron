import 'dart:convert';
import 'dart:math';

/// How an employee looks: indexes into the sprite color/style tables.
class EmployeeLook {
  const EmployeeLook({
    required this.skin,
    required this.hairStyle,
    required this.hairColor,
    required this.shirt,
    required this.pants,
  });

  final int skin;
  final int hairStyle;
  final int hairColor;
  final int shirt;
  final int pants;

  Map<String, dynamic> toJson() => {
        'skin': skin,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'shirt': shirt,
        'pants': pants,
      };

  factory EmployeeLook.fromJson(Map<String, dynamic> json) => EmployeeLook(
        skin: (json['skin'] as num?)?.toInt() ?? 0,
        hairStyle: (json['hairStyle'] as num?)?.toInt() ?? 0,
        hairColor: (json['hairColor'] as num?)?.toInt() ?? 0,
        shirt: (json['shirt'] as num?)?.toInt() ?? 0,
        pants: (json['pants'] as num?)?.toInt() ?? 0,
      );

  static EmployeeLook random(Random rng) => EmployeeLook(
        skin: rng.nextInt(4),
        hairStyle: rng.nextInt(3),
        hairColor: rng.nextInt(7),
        shirt: rng.nextInt(8),
        pants: rng.nextInt(3),
      );
}

/// Personality tunes the simulation: how fast energy drains, how chatty
/// someone is, their walking pace and the flavor line on their profile card.
class Personality {
  const Personality(
    this.id,
    this.label, {
    required this.tagline,
    this.energyDrain = 1.0,
    this.chattiness = 1.0,
    this.coffeeLove = 1.0,
    this.paceFactor = 1.0,
  });

  final String id;
  final String label;
  final String tagline;
  final double energyDrain; // >1 tires quickly
  final double chattiness; // >1 seeks chats more
  final double coffeeLove; // >1 takes more coffee breaks
  final double paceFactor; // walk speed multiplier

  static const all = <Personality>[
    Personality('coffeeAddict', 'Coffee addict',
        tagline: 'Runs on espresso and deadlines.',
        coffeeLove: 1.9, energyDrain: 1.25, paceFactor: 1.15),
    Personality('nightOwl', 'Night owl',
        tagline: 'Best commits happen after midnight.',
        energyDrain: 0.8, chattiness: 0.7),
    Personality('socialButterfly', 'Social butterfly',
        tagline: 'Knows everyone, including the plants.',
        chattiness: 2.0, energyDrain: 1.1),
    Personality('perfectionist', 'Perfectionist',
        tagline: 'Will realign that pixel. Again.',
        energyDrain: 1.2, chattiness: 0.8),
    Personality('zenMaster', 'Zen master',
        tagline: 'Inbox zero, pulse sixty.',
        energyDrain: 0.65, chattiness: 0.9, paceFactor: 0.85),
    Personality('memeLord', 'Meme lord',
        tagline: 'Communicates exclusively in reaction gifs.',
        chattiness: 1.6, coffeeLove: 1.2),
    Personality('speedrunner', 'Speedrunner',
        tagline: 'Walks fast, ships faster.',
        paceFactor: 1.45, energyDrain: 1.3),
    Personality('daydreamer', 'Daydreamer',
        tagline: 'Currently somewhere else entirely.',
        energyDrain: 0.9, chattiness: 1.1, paceFactor: 0.8),
    Personality('plantParent', 'Plant parent',
        tagline: 'The ficus has a name and a backstory.',
        chattiness: 1.2, coffeeLove: 0.7),
    Personality('visionary', 'Visionary',
        tagline: 'Sees the big picture. Misses the standup.',
        chattiness: 1.3, energyDrain: 0.9),
  ];

  static Personality byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

/// The persisted part of an employee (everything the simulation can't
/// recompute): identity, look, and an optionally pinned real task.
class EmployeeSpec {
  const EmployeeSpec({
    required this.id,
    required this.name,
    required this.role,
    required this.personalityId,
    required this.look,
    this.taskId,
  });

  final String id;
  final String name;
  final String role;
  final String personalityId;
  final EmployeeLook look;

  /// Optional real MindNoron task this employee is "working on".
  final String? taskId;

  Personality get personality => Personality.byId(personalityId);

  EmployeeSpec copyWith({
    String? name,
    String? role,
    String? personalityId,
    EmployeeLook? look,
    String? Function()? taskId,
  }) =>
      EmployeeSpec(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        personalityId: personalityId ?? this.personalityId,
        look: look ?? this.look,
        taskId: taskId != null ? taskId() : this.taskId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'personality': personalityId,
        'look': look.toJson(),
        if (taskId != null) 'taskId': taskId,
      };

  factory EmployeeSpec.fromJson(Map<String, dynamic> json) => EmployeeSpec(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unnamed',
        role: json['role'] as String? ?? 'Generalist',
        personalityId: json['personality'] as String? ?? 'zenMaster',
        look: EmployeeLook.fromJson(
            (json['look'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ??
                const {}),
        taskId: json['taskId'] as String?,
      );

  static String encodeList(List<EmployeeSpec> staff) =>
      jsonEncode([for (final e in staff) e.toJson()]);

  static List<EmployeeSpec> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => EmployeeSpec.fromJson(m.cast<String, dynamic>()))
            .where((e) => e.id.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}

/// The founding team of MindNoron Inc.
List<EmployeeSpec> defaultStaff() => const [
      EmployeeSpec(
        id: 'emp-mai',
        name: 'Mai',
        role: 'Product Designer',
        personalityId: 'perfectionist',
        look: EmployeeLook(
            skin: 0, hairStyle: 1, hairColor: 0, shirt: 5, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-tuan',
        name: 'Tuấn',
        role: 'Backend Engineer',
        personalityId: 'coffeeAddict',
        look: EmployeeLook(
            skin: 1, hairStyle: 0, hairColor: 0, shirt: 1, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-linh',
        name: 'Linh',
        role: 'Product Manager',
        personalityId: 'socialButterfly',
        look: EmployeeLook(
            skin: 0, hairStyle: 1, hairColor: 1, shirt: 0, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-duc',
        name: 'Đức',
        role: 'QA Engineer',
        personalityId: 'nightOwl',
        look: EmployeeLook(
            skin: 2, hairStyle: 2, hairColor: 0, shirt: 6, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-an',
        name: 'An',
        role: 'Frontend Engineer',
        personalityId: 'memeLord',
        look: EmployeeLook(
            skin: 1, hairStyle: 2, hairColor: 3, shirt: 2, pants: 1),
      ),
      EmployeeSpec(
        id: 'emp-ha',
        name: 'Hà',
        role: 'Data Analyst',
        personalityId: 'zenMaster',
        look: EmployeeLook(
            skin: 0, hairStyle: 1, hairColor: 4, shirt: 3, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-minh',
        name: 'Minh',
        role: 'Intern',
        personalityId: 'speedrunner',
        look: EmployeeLook(
            skin: 3, hairStyle: 0, hairColor: 0, shirt: 4, pants: 1),
      ),
      EmployeeSpec(
        id: 'emp-bao',
        name: 'Bảo',
        role: 'CEO & Founder',
        personalityId: 'visionary',
        look: EmployeeLook(
            skin: 2, hairStyle: 0, hairColor: 5, shirt: 7, pants: 2),
      ),
    ];

const hireNamePool = <String>[
  'Trang', 'Khoa', 'Vy', 'Phúc', 'Thảo', 'Nam', 'Chi', 'Quân', 'Ngọc',
  'Huy', 'Lan', 'Sơn', 'Yến', 'Đạt', 'Hương', 'Tâm', 'Nhi', 'Dũng',
];

const hireRolePool = <String>[
  'Fullstack Engineer',
  'UX Researcher',
  'DevOps Engineer',
  'Marketing Lead',
  'Office Dog Walker',
  'Scrum Master',
  'Tech Writer',
  'Growth Hacker',
  'Chief Vibes Officer',
];

/// Builds a fresh hire with a random identity (avoiding names already used).
EmployeeSpec rollNewHire(Random rng, List<EmployeeSpec> current) {
  final used = current.map((e) => e.name).toSet();
  final names = hireNamePool.where((n) => !used.contains(n)).toList();
  final name = names.isEmpty
      ? 'Noron #${rng.nextInt(900) + 100}'
      : names[rng.nextInt(names.length)];
  return EmployeeSpec(
    id: 'emp-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
    name: name,
    role: hireRolePool[rng.nextInt(hireRolePool.length)],
    personalityId:
        Personality.all[rng.nextInt(Personality.all.length)].id,
    look: EmployeeLook.random(rng),
  );
}
