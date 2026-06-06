import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// CRUD + search for Markdown [Notes].
class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;

  Future<String> create({String title = '', String content = ''}) async {
    final id = _uuid.v4();
    await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            id: id,
            title: Value(title),
            content: Value(content),
          ),
        );
    return id;
  }

  Future<void> update(String id, {String? title, String? content}) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        title: title == null ? const Value.absent() : Value(title),
        content: content == null ? const Value.absent() : Value(content),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  Stream<List<Note>> watchAll() {
    return (_db.select(_db.notes)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<List<Note>> search(String query) {
    final like = '%$query%';
    return (_db.select(_db.notes)
          ..where((t) =>
              t.deletedAt.isNull() &
              (t.title.like(like) | t.content.like(like))))
        .get();
  }
}

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(databaseProvider));
});

final allNotesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchAll();
});
