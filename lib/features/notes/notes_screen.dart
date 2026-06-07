import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Follow a `[[wikilink]]`: select the note with that title, creating it if it
  /// does not exist yet (Roam/Obsidian-style).
  Future<void> _openByTitle(List<Note> notes, String title) async {
    final lower = title.toLowerCase();
    for (final n in notes) {
      if (n.title.toLowerCase() == lower) {
        setState(() => _selectedId = n.id);
        return;
      }
    }
    final id = await ref.read(notesRepositoryProvider).create(title: title);
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
                    : _NoteEditor(
                        key: ValueKey(selected.id),
                        note: selected,
                        allNotes: notes,
                        onOpenLink: (title) => _openByTitle(notes, title),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor({
    super.key,
    required this.note,
    required this.allNotes,
    required this.onOpenLink,
  });

  final Note note;
  final List<Note> allNotes;
  final ValueChanged<String> onOpenLink;

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.note.title);
  late final TextEditingController _content =
      TextEditingController(text: widget.note.content);
  bool _preview = false;

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

  Future<void> _copyAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = '${_title.text}\n\n${_content.text}'.trim();
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Note copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Notes (other than this one) whose content links to this note's title.
  List<Note> get _backlinks {
    final title = _title.text.trim();
    if (title.isEmpty) return const [];
    return widget.allNotes
        .where((n) =>
            n.id != widget.note.id && NotesRepository.linksTo(n, title))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backlinks = _backlinks;

    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.edit_outlined, size: 18),
                    label: Text('Edit'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.visibility_outlined, size: 18),
                    label: Text('Preview'),
                  ),
                ],
                selected: {_preview},
                onSelectionChanged: (s) => setState(() => _preview = s.first),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _copyAll,
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
          TextField(
            controller: _title,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
            onChanged: (_) {
              _save();
              setState(() {}); // refresh backlinks against the new title
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _preview
                ? SingleChildScrollView(
                    child: MarkdownBody(
                      text: _content.text,
                      onTapLink: widget.onOpenLink,
                    ),
                  )
                : TextField(
                    controller: _content,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText:
                          'Write in Markdown... link notes with [[Title]]',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _save(),
                  ),
          ),
          if (backlinks.isNotEmpty) _Backlinks(notes: backlinks),
        ],
      ),
    );
  }
}

/// "Linked from" panel — the inbound half of the second-brain graph.
class _Backlinks extends StatelessWidget {
  const _Backlinks({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Linked from (${notes.length})',
                  style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final n in notes)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(n.title.isEmpty ? '(untitled)' : n.title),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minimal Markdown renderer — enough for calm note-taking without a heavy
/// dependency. Supports `#`/`##`/`###` headings, `- ` bullets, `**bold**`,
/// and `[[wikilinks]]` (tappable, via [onTapLink]).
class MarkdownBody extends StatelessWidget {
  const MarkdownBody({super.key, required this.text, required this.onTapLink});

  final String text;
  final ValueChanged<String> onTapLink;

  static final _wikilink = RegExp(r'\[\[([^\[\]]+)\]\]');
  static final _bold = RegExp(r'\*\*([^*]+)\*\*');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (text.trim().isEmpty) {
      return Text('Nothing to preview yet.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final blocks = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 8));
      } else if (line.startsWith('### ')) {
        blocks.add(_para(context, line.substring(4), theme.textTheme.titleSmall));
      } else if (line.startsWith('## ')) {
        blocks
            .add(_para(context, line.substring(3), theme.textTheme.titleMedium));
      } else if (line.startsWith('# ')) {
        blocks
            .add(_para(context, line.substring(2), theme.textTheme.titleLarge));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(
                  child: _para(context, line.substring(2),
                      theme.textTheme.bodyMedium)),
            ],
          ),
        ));
      } else {
        blocks.add(_para(context, line, theme.textTheme.bodyMedium));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  /// Render one line into a [RichText], turning `**bold**` and `[[links]]` into
  /// styled / tappable spans.
  Widget _para(BuildContext context, String line, TextStyle? base) {
    final theme = Theme.of(context);
    final style = base ?? theme.textTheme.bodyMedium;
    final spans = <InlineSpan>[];

    // Tokenize by wikilink first; bold is applied to the plain segments.
    var index = 0;
    for (final m in _wikilink.allMatches(line)) {
      if (m.start > index) {
        spans.addAll(_boldSpans(line.substring(index, m.start), style));
      }
      final title = m.group(1)!.trim();
      spans.add(TextSpan(
        text: title,
        style: style?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: _LinkTapRecognizer(() => onTapLink(title)),
      ));
      index = m.end;
    }
    if (index < line.length) {
      spans.addAll(_boldSpans(line.substring(index), style));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(TextSpan(style: style, children: spans)),
    );
  }

  List<InlineSpan> _boldSpans(String text, TextStyle? style) {
    final spans = <InlineSpan>[];
    var index = 0;
    for (final m in _bold.allMatches(text)) {
      if (m.start > index) {
        spans.add(TextSpan(text: text.substring(index, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: (style ?? const TextStyle())
            .copyWith(fontWeight: FontWeight.bold),
      ));
      index = m.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return spans;
  }
}

/// A tap recognizer for inline wikilink spans. Kept tiny so the renderer needs
/// no external gesture dependency.
class _LinkTapRecognizer extends TapGestureRecognizer {
  _LinkTapRecognizer(VoidCallback onTap) {
    this.onTap = onTap;
  }
}
