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
}
