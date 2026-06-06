import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/notes_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/section_scaffold.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String? _selectedId;

  Future<void> _newNote() async {
    final id = await ref.read(notesRepositoryProvider).create();
    setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notesAsync = ref.watch(allNotesProvider);

    return SectionScaffold(
      title: l10n.navNotes,
      actions: [
        FilledButton.icon(
          onPressed: _newNote,
          icon: const Icon(Icons.add),
          label: const Text('New note'),
        ),
      ],
      child: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load notes: $e')),
        data: (notes) {
          Note? selected;
          for (final n in notes) {
            if (n.id == _selectedId) {
              selected = n;
              break;
            }
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 300,
                child: notes.isEmpty
                    ? const ComingSoon(label: 'No notes yet')
                    : ListView.separated(
                        itemCount: notes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final n = notes[i];
                          final title =
                              n.title.isEmpty ? '(untitled)' : n.title;
                          final snippet = n.content.isEmpty
                              ? ''
                              : n.content.split('\n').first;
                          return ListTile(
                            selected: n.id == _selectedId,
                            title: Text(title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: snippet.isEmpty
                                ? null
                                : Text(snippet,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            onTap: () => setState(() => _selectedId = n.id),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () async {
                                await ref
                                    .read(notesRepositoryProvider)
                                    .softDelete(n.id);
                                if (_selectedId == n.id) {
                                  setState(() => _selectedId = null);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const ComingSoon(label: 'Select or create a note')
                    : _NoteEditor(key: ValueKey(selected.id), note: selected),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor({super.key, required this.note});

  final Note note;

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.note.title);
  late final TextEditingController _content =
      TextEditingController(text: widget.note.content);

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(notesRepositoryProvider).update(
          widget.note.id,
          title: _title.text,
          content: _content.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _content,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Write in Markdown...',
                border: InputBorder.none,
              ),
              onChanged: (_) => _save(),
            ),
          ),
        ],
      ),
    );
  }
}
