import 'dart:convert';

/// The player's office economy: coins earned from real productivity, items
/// unlocked from the shop, and bookkeeping so the same task is never paid
/// twice across rebuilds/restarts.
///
/// Persisted as JSON under the `officeEconomyV1` settings key. Positions of
/// furniture the player places live separately in [PlacedItem].
class OfficeEconomy {
  const OfficeEconomy({
    this.coins = 0,
    this.totalEarned = 0,
    this.unlockedItemIds = const <String>{},
    this.creditedTaskIds = const <String>{},
    this.focusSessions = 0,
  });

  /// Spendable balance.
  final int coins;

  /// Lifetime coins earned (never spent down) — drives achievements.
  final int totalEarned;

  /// Shop items the player owns and may place in build mode.
  final Set<String> unlockedItemIds;

  /// Task ids already paid out, so we stay idempotent against the
  /// completed-tasks stream re-emitting on every rebuild.
  final Set<String> creditedTaskIds;

  /// Count of focus sessions rewarded (for achievements/feed).
  final int focusSessions;

  OfficeEconomy copyWith({
    int? coins,
    int? totalEarned,
    Set<String>? unlockedItemIds,
    Set<String>? creditedTaskIds,
    int? focusSessions,
  }) =>
      OfficeEconomy(
        coins: coins ?? this.coins,
        totalEarned: totalEarned ?? this.totalEarned,
        unlockedItemIds: unlockedItemIds ?? this.unlockedItemIds,
        creditedTaskIds: creditedTaskIds ?? this.creditedTaskIds,
        focusSessions: focusSessions ?? this.focusSessions,
      );

  /// Adds [amount] coins (both spendable and lifetime), optionally recording
  /// [taskId] as credited.
  OfficeEconomy earn(int amount, {String? taskId}) => copyWith(
        coins: coins + amount,
        totalEarned: totalEarned + amount,
        creditedTaskIds:
            taskId == null ? null : {...creditedTaskIds, taskId},
      );

  /// Spends [amount] coins if affordable; returns the same instance otherwise.
  OfficeEconomy? trySpend(int amount) =>
      coins >= amount ? copyWith(coins: coins - amount) : null;

  bool owns(String itemId) => unlockedItemIds.contains(itemId);

  OfficeEconomy unlock(String itemId) =>
      copyWith(unlockedItemIds: {...unlockedItemIds, itemId});

  bool hasCredited(String taskId) => creditedTaskIds.contains(taskId);

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'totalEarned': totalEarned,
        'unlocked': unlockedItemIds.toList(),
        // Cap the ledger so it can't grow without bound; the most recent ids
        // are the only ones the live stream can re-emit.
        'credited': creditedTaskIds.length > 500
            ? creditedTaskIds.toList().sublist(creditedTaskIds.length - 500)
            : creditedTaskIds.toList(),
        'focusSessions': focusSessions,
      };

  factory OfficeEconomy.fromJson(Map<String, dynamic> json) => OfficeEconomy(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        totalEarned: (json['totalEarned'] as num?)?.toInt() ?? 0,
        unlockedItemIds: _stringSet(json['unlocked']),
        creditedTaskIds: _stringSet(json['credited']),
        focusSessions: (json['focusSessions'] as num?)?.toInt() ?? 0,
      );

  String encode() => jsonEncode(toJson());

  static OfficeEconomy decode(String? raw) {
    if (raw == null || raw.isEmpty) return const OfficeEconomy();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return OfficeEconomy.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return const OfficeEconomy();
  }

  static Set<String> _stringSet(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return const <String>{};
  }
}

/// A piece of furniture the player has placed in build mode, anchored at a
/// tile with a rotation. The catalog item id resolves to a sprite + footprint.
class PlacedItem {
  const PlacedItem({
    required this.itemId,
    required this.tx,
    required this.ty,
    this.rot = 0,
  });

  final String itemId;
  final int tx;
  final int ty;

  /// 0..3 quarter turns.
  final int rot;

  PlacedItem copyWith({int? tx, int? ty, int? rot}) => PlacedItem(
        itemId: itemId,
        tx: tx ?? this.tx,
        ty: ty ?? this.ty,
        rot: rot ?? this.rot,
      );

  Map<String, dynamic> toJson() => {
        'item': itemId,
        'tx': tx,
        'ty': ty,
        if (rot != 0) 'rot': rot,
      };

  factory PlacedItem.fromJson(Map<String, dynamic> json) => PlacedItem(
        itemId: json['item'] as String? ?? '',
        tx: (json['tx'] as num?)?.toInt() ?? 0,
        ty: (json['ty'] as num?)?.toInt() ?? 0,
        rot: (json['rot'] as num?)?.toInt() ?? 0,
      );

  static String encodeList(List<PlacedItem> items) =>
      jsonEncode([for (final i in items) i.toJson()]);

  static List<PlacedItem> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => PlacedItem.fromJson(m.cast<String, dynamic>()))
            .where((i) => i.itemId.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
