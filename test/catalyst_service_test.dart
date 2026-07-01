import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mind_noron/features/catalyst/catalyst_idea.dart';
import 'package:mind_noron/features/catalyst/catalyst_service.dart';

String _successBody() {
  final ideasJson = jsonEncode({
    'ideas': [
      for (final n in ['A', 'B', 'C'])
        {
          'conceptName': 'Concept $n',
          'paradigmShift': 'Shift $n',
          'coreMechanism': 'Mech $n',
          'asymmetricAdvantage': 'Edge $n',
        },
    ],
  });
  return jsonEncode({
    'stop_reason': 'end_turn',
    'content': [
      {'type': 'thinking', 'thinking': ''},
      {'type': 'text', 'text': ideasJson},
    ],
    'usage': {
      'input_tokens': 1200,
      'output_tokens': 800,
      'cache_read_input_tokens': 100,
    },
  });
}

CatalystService _serviceReturning(String body, int status) => CatalystService(
      client: MockClient((_) async => http.Response(body, status)),
    );

void main() {
  group('CatalystService.generate', () {
    test('parses three ideas, tags the brief, and totals usage', () async {
      final client = MockClient((req) async {
        expect(req.headers['x-api-key'], 'test-key');
        expect(req.headers['anthropic-version'], '2023-06-01');
        return http.Response(_successBody(), 200);
      });
      final result = await CatalystService(client: client)
          .generate('giảm ô nhiễm không khí', 'test-key');

      expect(result.ideas.length, 3);
      expect(result.ideas.first.conceptName, 'Concept A');
      expect(result.ideas.first.coreMechanism, 'Mech A');
      expect(result.ideas.first.brief, 'giảm ô nhiễm không khí');
      // 1200 input + 100 cache read folded together.
      expect(result.usage.inputTokens, 1300);
      expect(result.usage.outputTokens, 800);
      expect(result.usage.total, 2100);
    });

    test('empty API key throws missingKey', () {
      expect(
        () => _serviceReturning('{}', 200).generate('brief', '   '),
        throwsA(isA<CatalystException>()
            .having((e) => e.kind, 'kind', CatalystError.missingKey)),
      );
    });

    test('401 throws unauthorized', () {
      expect(
        _serviceReturning('{}', 401).generate('brief', 'k'),
        throwsA(isA<CatalystException>()
            .having((e) => e.kind, 'kind', CatalystError.unauthorized)),
      );
    });

    test('429 throws rateLimited', () {
      expect(
        _serviceReturning('{}', 429).generate('brief', 'k'),
        throwsA(isA<CatalystException>()
            .having((e) => e.kind, 'kind', CatalystError.rateLimited)),
      );
    });

    test('refusal stop_reason throws refused', () {
      final body = jsonEncode({
        'stop_reason': 'refusal',
        'content': <dynamic>[],
        'stop_details': {'category': 'cyber'},
      });
      expect(
        _serviceReturning(body, 200).generate('brief', 'k'),
        throwsA(isA<CatalystException>()
            .having((e) => e.kind, 'kind', CatalystError.refused)),
      );
    });
  });

  group('CatalystIdea', () {
    test('encode/decode round-trips all fields', () {
      final idea = CatalystIdea(
        id: 'x1',
        brief: 'b',
        conceptName: 'n',
        paradigmShift: 's',
        coreMechanism: 'm',
        asymmetricAdvantage: 'e',
        createdAt: DateTime.parse('2026-07-01T10:00:00.000'),
        starred: true,
      );
      final decoded =
          CatalystIdea.decodeList(CatalystIdea.encodeList([idea]));

      expect(decoded, hasLength(1));
      expect(decoded.first.id, 'x1');
      expect(decoded.first.conceptName, 'n');
      expect(decoded.first.asymmetricAdvantage, 'e');
      expect(decoded.first.starred, isTrue);
    });

    test('decodeList tolerates junk', () {
      expect(CatalystIdea.decodeList(null), isEmpty);
      expect(CatalystIdea.decodeList('not json'), isEmpty);
      expect(CatalystIdea.decodeList('[{"no":"name"}]'), isEmpty);
    });
  });
}
