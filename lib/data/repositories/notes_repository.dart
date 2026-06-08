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
  static const _captureTitleLimit = 80;

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

  /// Turn quick-capture text into note fields without losing the original idea.
  static ({String title, String content}) fieldsFromCapture(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return (title: 'Untitled capture', content: '');

    final lines = trimmed.split(RegExp(r'\r?\n'));
    final firstTextIndex = lines.indexWhere((line) => line.trim().isNotEmpty);
    final titleSource = lines[firstTextIndex < 0 ? 0 : firstTextIndex].trim();
    final title = _clampedTitle(titleSource);
    final bodyLines =
        firstTextIndex < 0 ? const <String>[] : lines.skip(firstTextIndex + 1);
    var content = bodyLines.join('\n').trim();

    if (content.isEmpty && titleSource.length > _captureTitleLimit) {
      content = trimmed;
    }
    return (title: title, content: content);
  }

  static String _clampedTitle(String title) {
    if (title.length <= _captureTitleLimit) return title;
    return '${title.substring(0, _captureTitleLimit - 3).trimRight()}...';
  }

  /// Promote an inbox item into a note, marking the item processed.
  Future<String> convertInboxToNote(InboxItem item) async {
    final fields = fieldsFromCapture(item.content);
    late String id;
    await _db.transaction(() async {
      id = await create(title: fields.title, content: fields.content);
      await (_db.update(_db.inboxItems)..where((t) => t.id.equals(item.id)))
          .write(
        InboxItemsCompanion(
          isProcessed: const Value(true),
          updatedAt: Value(DateTime.now()),
          isDirty: const Value(true),
        ),
      );
    });
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

  /// `[[Wiki Link]]` targets referenced inside a note's content. Powers the
  /// note↔note backlink graph (PLAN.md §4.8).
  static final _wikilink = RegExp(r'\[\[([^\[\]]+)\]\]');

  static List<String> linkTargets(String content) {
    return _wikilink
        .allMatches(content)
        .map((m) => m.group(1)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Whether [note] links to a note titled [title] (case-insensitive).
  static bool linksTo(Note note, String title) {
    final lower = title.toLowerCase();
    return linkTargets(note.content).any((t) => t.toLowerCase() == lower);
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
