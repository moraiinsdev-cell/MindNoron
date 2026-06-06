import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// Reads/writes for the Inbox (quick-capture) collection.
class InboxRepository {
  InboxRepository(this._db);

  final AppDatabase _db;

  /// Persist a captured note. Returns nothing — capture must feel instant.
  Future<void> capture(String content, {String source = 'manual'}) {
    return _db.into(_db.inboxItems).insert(
          InboxItemsCompanion.insert(
            id: _uuid.v4(),
            content: content.trim(),
            source: Value(source),
          ),
        );
  }

  /// Soft-delete an inbox item (discard without converting).
  Future<void> discard(String id) {
    return (_db.update(_db.inboxItems)..where((t) => t.id.equals(id))).write(
      InboxItemsCompanion(
        isProcessed: const Value(true),
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Live stream of unprocessed inbox items, newest first.
  Stream<List<InboxItem>> watchUnprocessed() {
    return (_db.select(_db.inboxItems)
          ..where((t) => t.isProcessed.equals(false) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }
}

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  return InboxRepository(ref.watch(databaseProvider));
});

/// Live unprocessed inbox items for the UI.
final unprocessedInboxProvider = StreamProvider<List<InboxItem>>((ref) {
  return ref.watch(inboxRepositoryProvider).watchUnprocessed();
});
