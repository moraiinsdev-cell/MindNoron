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
    this.floor = 0,
    this.taskId,
  });

  final String id;
  final String name;
  final String role;
  final String personalityId;
  final EmployeeLook look;

  /// Which building floor this employee works on (0-based).
  final int floor;

  /// Optional real MindNoron task this employee is "working on".
  final String? taskId;

  Personality get personality => Personality.byId(personalityId);

  EmployeeSpec copyWith({
    String? name,
    String? role,
    String? personalityId,
    EmployeeLook? look,
    int? floor,
    String? Function()? taskId,
  }) =>
      EmployeeSpec(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        personalityId: personalityId ?? this.personalityId,
        look: look ?? this.look,
        floor: floor ?? this.floor,
        taskId: taskId != null ? taskId() : this.taskId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'personality': personalityId,
        'look': look.toJson(),
        if (floor != 0) 'floor': floor,
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
        floor: (json['floor'] as num?)?.toInt() ?? 0,
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

/// The building's floors, ground (0) first. Each floor is its own department
/// with its own staff; the office screen shows one floor at a time.
const floorNames = <String>[
  'Operations',
  'Engineering',
  'Creative Studio',
  'Wellness',
  'Sky Lounge',
];

/// A short tagline shown under the floor name in the selector.
const floorTaglines = <String>[
  'Ops, logistics & finance',
  'Where the product gets built',
  'Design, art & story',
  'Gym, pool & recharge',
  'Bar, cinema & arcade',
];

int get floorCount => floorNames.length;

/// The founding team of MindNoron Inc. — a suspiciously familiar bunch of
/// "entrepreneurs" — now spread across five floors of the tower.
List<EmployeeSpec> defaultStaff() => const [
      // --- Floor 0: Operations -------------------------------------------
      EmployeeSpec(
        id: 'emp-elon',
        name: 'Elon',
        role: 'CEO & Chief Rocket Officer',
        personalityId: 'visionary',
        floor: 0,
        look: EmployeeLook(
            skin: 0, hairStyle: 0, hairColor: 1, shirt: 7, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-jeff',
        name: 'Jeff',
        role: 'Logistics & Same-Day Lead',
        personalityId: 'speedrunner',
        floor: 0,
        look: EmployeeLook(
            skin: 1, hairStyle: 0, hairColor: 5, shirt: 1, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-warren',
        name: 'Warren',
        role: 'Finance Oracle',
        personalityId: 'coffeeAddict',
        floor: 0,
        look: EmployeeLook(
            skin: 0, hairStyle: 0, hairColor: 2, shirt: 0, pants: 1),
      ),
      EmployeeSpec(
        id: 'emp-andy',
        name: 'Andy',
        role: 'Chief Operating Officer',
        personalityId: 'perfectionist',
        floor: 0,
        look: EmployeeLook(
            skin: 2, hairStyle: 0, hairColor: 1, shirt: 3, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-sheryl',
        name: 'Sheryl',
        role: 'Operations Lead',
        personalityId: 'socialButterfly',
        floor: 0,
        look: EmployeeLook(
            skin: 1, hairStyle: 1, hairColor: 2, shirt: 5, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-pat',
        name: 'Pat',
        role: 'Supply Chain Boss',
        personalityId: 'speedrunner',
        floor: 0,
        look: EmployeeLook(
            skin: 3, hairStyle: 2, hairColor: 0, shirt: 6, pants: 1),
      ),

      // --- Floor 1: Engineering ------------------------------------------
      EmployeeSpec(
        id: 'emp-bill',
        name: 'Bill',
        role: 'Chief Architect',
        personalityId: 'perfectionist',
        floor: 1,
        look: EmployeeLook(
            skin: 0, hairStyle: 0, hairColor: 0, shirt: 3, pants: 1),
      ),
      EmployeeSpec(
        id: 'emp-jensen',
        name: 'Jensen',
        role: 'GPU Whisperer',
        personalityId: 'nightOwl',
        floor: 1,
        look: EmployeeLook(
            skin: 2, hairStyle: 2, hairColor: 0, shirt: 7, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-demis',
        name: 'Demis',
        role: 'Head of Deep Thinking',
        personalityId: 'zenMaster',
        floor: 1,
        look: EmployeeLook(
            skin: 0, hairStyle: 0, hairColor: 0, shirt: 6, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-linus',
        name: 'Linus',
        role: 'Kernel Maintainer',
        personalityId: 'nightOwl',
        floor: 1,
        look: EmployeeLook(
            skin: 0, hairStyle: 0, hairColor: 1, shirt: 2, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-ada',
        name: 'Ada',
        role: 'Systems Engineer',
        personalityId: 'perfectionist',
        floor: 1,
        look: EmployeeLook(
            skin: 1, hairStyle: 1, hairColor: 4, shirt: 4, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-grace',
        name: 'Grace',
        role: 'Compiler Wizard',
        personalityId: 'zenMaster',
        floor: 1,
        look: EmployeeLook(
            skin: 2, hairStyle: 1, hairColor: 0, shirt: 1, pants: 2),
      ),

      // --- Floor 2: Creative Studio --------------------------------------
      EmployeeSpec(
        id: 'emp-mark',
        name: 'Mark',
        role: 'Metaverse Engineer',
        personalityId: 'memeLord',
        floor: 2,
        look: EmployeeLook(
            skin: 0, hairStyle: 2, hairColor: 0, shirt: 6, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-tim',
        name: 'Tim',
        role: 'Design Director',
        personalityId: 'zenMaster',
        floor: 2,
        look: EmployeeLook(
            skin: 1, hairStyle: 0, hairColor: 5, shirt: 4, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-reed',
        name: 'Reed',
        role: 'Chief Binge Officer',
        personalityId: 'daydreamer',
        floor: 2,
        look: EmployeeLook(
            skin: 0, hairStyle: 2, hairColor: 1, shirt: 0, pants: 1),
      ),
      EmployeeSpec(
        id: 'emp-walt',
        name: 'Walt',
        role: 'Animation Lead',
        personalityId: 'daydreamer',
        floor: 2,
        look: EmployeeLook(
            skin: 1, hairStyle: 0, hairColor: 2, shirt: 5, pants: 1),
      ),
      EmployeeSpec(
        id: 'emp-hayao',
        name: 'Hayao',
        role: 'Art Director',
        personalityId: 'zenMaster',
        floor: 2,
        look: EmployeeLook(
            skin: 2, hairStyle: 0, hairColor: 0, shirt: 7, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-stan',
        name: 'Stan',
        role: 'Story Editor',
        personalityId: 'memeLord',
        floor: 2,
        look: EmployeeLook(
            skin: 0, hairStyle: 2, hairColor: 3, shirt: 1, pants: 0),
      ),

      // --- Floor 3: Wellness ---------------------------------------------
      EmployeeSpec(
        id: 'emp-oprah',
        name: 'Oprah',
        role: 'Chief Vibes Officer',
        personalityId: 'socialButterfly',
        floor: 3,
        look: EmployeeLook(
            skin: 3, hairStyle: 1, hairColor: 0, shirt: 5, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-lisa',
        name: 'Lisa',
        role: 'Chief Silicon Officer',
        personalityId: 'perfectionist',
        floor: 3,
        look: EmployeeLook(
            skin: 1, hairStyle: 1, hairColor: 0, shirt: 2, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-brian',
        name: 'Brian',
        role: 'Head of Belonging',
        personalityId: 'socialButterfly',
        floor: 3,
        look: EmployeeLook(
            skin: 2, hairStyle: 0, hairColor: 3, shirt: 4, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-serena',
        name: 'Serena',
        role: 'Head of Fitness',
        personalityId: 'speedrunner',
        floor: 3,
        look: EmployeeLook(
            skin: 3, hairStyle: 1, hairColor: 0, shirt: 6, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-simone',
        name: 'Simone',
        role: 'Yoga Master',
        personalityId: 'zenMaster',
        floor: 3,
        look: EmployeeLook(
            skin: 2, hairStyle: 1, hairColor: 1, shirt: 7, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-usain',
        name: 'Usain',
        role: 'Track Coach',
        personalityId: 'speedrunner',
        floor: 3,
        look: EmployeeLook(
            skin: 3, hairStyle: 0, hairColor: 0, shirt: 3, pants: 1),
      ),

      // --- Floor 4: Sky Lounge -------------------------------------------
      EmployeeSpec(
        id: 'emp-gordon',
        name: 'Gordon',
        role: 'Executive Chef',
        personalityId: 'perfectionist',
        floor: 4,
        look: EmployeeLook(
            skin: 0, hairStyle: 0, hairColor: 2, shirt: 7, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-martha',
        name: 'Martha',
        role: 'Hospitality Lead',
        personalityId: 'socialButterfly',
        floor: 4,
        look: EmployeeLook(
            skin: 1, hairStyle: 1, hairColor: 2, shirt: 5, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-wolfgang',
        name: 'Wolfgang',
        role: 'Head Mixologist',
        personalityId: 'coffeeAddict',
        floor: 4,
        look: EmployeeLook(
            skin: 0, hairStyle: 0, hairColor: 1, shirt: 1, pants: 2),
      ),
      EmployeeSpec(
        id: 'emp-dwayne',
        name: 'Dwayne',
        role: 'Chief Host',
        personalityId: 'socialButterfly',
        floor: 4,
        look: EmployeeLook(
            skin: 2, hairStyle: 0, hairColor: 0, shirt: 4, pants: 1),
      ),
      EmployeeSpec(
        id: 'emp-vera',
        name: 'Vera',
        role: 'Concierge',
        personalityId: 'daydreamer',
        floor: 4,
        look: EmployeeLook(
            skin: 1, hairStyle: 1, hairColor: 4, shirt: 6, pants: 0),
      ),
      EmployeeSpec(
        id: 'emp-keith',
        name: 'Keith',
        role: 'Sommelier',
        personalityId: 'coffeeAddict',
        floor: 4,
        look: EmployeeLook(
            skin: 3, hairStyle: 2, hairColor: 0, shirt: 0, pants: 2),
      ),
    ];

/// Staff on a given floor.
List<EmployeeSpec> staffOnFloor(List<EmployeeSpec> all, int floor) =>
    [for (final e in all) if (e.floor == floor) e];

/// Walk-in candidates — the rest of the billionaire cinematic universe.
const hireNamePool = <String>[
  'Sam', 'Satya', 'Sundar', 'Larry', 'Sergey', 'Jack', 'Steve', 'Pony',
  'Masa', 'Vượng', 'Bernard', 'Mukesh', 'Richard', 'Jamie', 'Michael',
];

const hireRolePool = <String>[
  'Rocket Scientist',
  'Search Quality Rater',
  'Cloud Evangelist',
  'AI Researcher',
  'Hostile Takeover Intern',
  'Crypto Recovery Specialist',
  'Space Tourism Agent',
  'Chief Meme Officer',
  'Synergy Consultant',
  'Disruption Lead',
];

/// Builds a fresh hire with a random identity (avoiding names already used),
/// placed on [floor].
EmployeeSpec rollNewHire(Random rng, List<EmployeeSpec> current,
    {int floor = 0}) {
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
    floor: floor,
    look: EmployeeLook.random(rng),
  );
}
