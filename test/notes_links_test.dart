import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/data/repositories/notes_repository.dart';

void main() {
  group('NotesRepository.linkTargets', () {
    test('extracts a single wikilink', () {
      expect(NotesRepository.linkTargets('see [[Ideas]] later'), ['Ideas']);
    });

    test('extracts multiple wikilinks and trims whitespace', () {
      expect(
        NotesRepository.linkTargets('[[ Alpha ]] and [[Beta]]'),
        ['Alpha', 'Beta'],
      );
    });

    test('ignores empty brackets and plain text', () {
      expect(NotesRepository.linkTargets('no links here [[]]'), isEmpty);
    });

    test('handles content with no links', () {
      expect(NotesRepository.linkTargets('just prose'), isEmpty);
    });
  });

  group('NotesRepository.fieldsFromCapture', () {
    test('uses a single-line capture as the note title', () {
      final fields = NotesRepository.fieldsFromCapture('Idea for tomorrow');
      expect(fields.title, 'Idea for tomorrow');
      expect(fields.content, isEmpty);
    });

    test('splits a multi-line capture into title and body', () {
      final fields = NotesRepository.fieldsFromCapture(
        'Meeting notes\n- follow up with Anh\n- send proposal',
      );
      expect(fields.title, 'Meeting notes');
      expect(fields.content, '- follow up with Anh\n- send proposal');
    });

    test('preserves a long single-line capture in the body', () {
      final long = 'x' * 120;
      final fields = NotesRepository.fieldsFromCapture(long);
      expect(fields.title.length, lessThanOrEqualTo(80));
      expect(fields.title.endsWith('...'), isTrue);
      expect(fields.content, long);
    });
  });
}
