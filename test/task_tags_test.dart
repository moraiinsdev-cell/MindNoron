import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/data/repositories/task_repository.dart';

void main() {
  group('TaskRepository.decodeTags', () {
    test('decodes a JSON list', () {
      expect(TaskRepository.decodeTags('["work","urgent"]'),
          ['work', 'urgent']);
    });

    test('empty string yields no tags', () {
      expect(TaskRepository.decodeTags(''), isEmpty);
    });

    test('empty JSON array yields no tags', () {
      expect(TaskRepository.decodeTags('[]'), isEmpty);
    });

    test('corrupt value falls back to empty', () {
      expect(TaskRepository.decodeTags('not json'), isEmpty);
    });
  });
}
