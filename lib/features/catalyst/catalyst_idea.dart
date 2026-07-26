import 'dart:convert';

/// One breakthrough concept produced by the AI Idea Catalyst.
///
/// Unlike the Office's offline [GeneratedIdea], a catalyst idea is the output of
/// a live LLM call (Claude) and carries the full four-part "Radical Innovation
/// Engine" breakdown: a shock concept name plus the paradigm shift, core
/// mechanism, and asymmetric advantage. Persisted so the player can revisit the
/// briefs they ran during a hackathon.
class CatalystIdea {
  CatalystIdea({
    required this.id,
    required this.brief,
    required this.conceptName,
    required this.paradigmShift,
    required this.coreMechanism,
    required this.asymmetricAdvantage,
    required this.createdAt,
    this.starred = false,
  });

  final String id;

  /// The brief/sentence the player entered that produced this idea.
  final String brief;

  /// Concept name — the punchy, differentiated concept name.
  final String conceptName;

  /// Paradigm shift — the blind spot 99% of teams miss.
  final String paradigmShift;

  /// Core mechanism — how the existing tech stack is wired off-label.
  final String coreMechanism;

  /// Asymmetric advantage — why traditional solutions become obsolete.
  final String asymmetricAdvantage;

  final DateTime createdAt;
  final bool starred;

  CatalystIdea copyWith({bool? starred}) => CatalystIdea(
        id: id,
        brief: brief,
        conceptName: conceptName,
        paradigmShift: paradigmShift,
        coreMechanism: coreMechanism,
        asymmetricAdvantage: asymmetricAdvantage,
        createdAt: createdAt,
        starred: starred ?? this.starred,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'brief': brief,
        'name': conceptName,
        'shift': paradigmShift,
        'mech': coreMechanism,
        'edge': asymmetricAdvantage,
        'at': createdAt.toIso8601String(),
        'star': starred,
      };

  static CatalystIdea? fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String?;
    if (name == null) return null;
    return CatalystIdea(
      id: j['id'] as String? ?? name.hashCode.toString(),
      brief: j['brief'] as String? ?? '',
      conceptName: name,
      paradigmShift: j['shift'] as String? ?? '',
      coreMechanism: j['mech'] as String? ?? '',
      asymmetricAdvantage: j['edge'] as String? ?? '',
      createdAt: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      starred: j['star'] as bool? ?? false,
    );
  }

  static String encodeList(List<CatalystIdea> ideas) =>
      jsonEncode([for (final i in ideas) i.toJson()]);

  static List<CatalystIdea> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            if (CatalystIdea.fromJson(e) case final idea?) idea,
      ];
    } catch (_) {
      return const [];
    }
  }
}
