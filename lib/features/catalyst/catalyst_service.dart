import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'catalyst_idea.dart';
import 'catalyst_prompt.dart';

/// Why a catalyst run failed — drives a friendly, actionable message in the UI.
enum CatalystError {
  missingKey,
  unauthorized,
  rateLimited,
  refused,
  network,
  badResponse,
}

/// A typed failure from [CatalystService]. [message] is safe to show the user.
class CatalystException implements Exception {
  const CatalystException(this.kind, this.message);

  final CatalystError kind;
  final String message;

  @override
  String toString() => message;
}

/// Token usage for one brainstorm round, so the player can watch spend. Cache
/// reads/writes are folded into [inputTokens] for an honest total.
class CatalystUsage {
  const CatalystUsage({required this.inputTokens, required this.outputTokens});

  final int inputTokens;
  final int outputTokens;

  int get total => inputTokens + outputTokens;

  static CatalystUsage fromJson(Object? j) {
    if (j is! Map) {
      return const CatalystUsage(inputTokens: 0, outputTokens: 0);
    }
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return CatalystUsage(
      inputTokens: n('input_tokens') +
          n('cache_read_input_tokens') +
          n('cache_creation_input_tokens'),
      outputTokens: n('output_tokens'),
    );
  }
}

/// One brainstorm round: the ideas plus the token usage that produced them.
class CatalystResult {
  const CatalystResult(this.ideas, this.usage);

  final List<CatalystIdea> ideas;
  final CatalystUsage usage;
}

/// Calls Claude (Anthropic Messages API) once per brief to produce three
/// breakthrough ideas. This is the app's only network feature — the Office idea
/// engine remains fully offline.
///
/// Dart has no official Anthropic SDK, so we hit the REST endpoint directly.
/// This runs in a desktop app (no browser), so there is no CORS concern.
class CatalystService {
  CatalystService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-opus-4-8';
  // 'high' balances idea quality against token spend per round; 'xhigh'/'max'
  // would think longer and cost noticeably more per brainstorm.
  static const _effort = 'high';
  static const _maxTokens = 12000; // hard ceiling; adaptive thinking shares it
  static const _timeout = Duration(seconds: 150);

  static const _uuid = Uuid();

  /// Runs the GOLD PROMPT against [brief] and returns the parsed ideas plus the
  /// round's token usage. Throws [CatalystException] on any failure.
  Future<CatalystResult> generate(String brief, String apiKey) async {
    final trimmedBrief = brief.trim();
    if (apiKey.trim().isEmpty) {
      throw const CatalystException(CatalystError.missingKey,
          'Add your Anthropic API key in Settings to generate ideas.');
    }
    if (trimmedBrief.isEmpty) {
      throw const CatalystException(
          CatalystError.badResponse, 'Enter a brief first.');
    }

    final body = jsonEncode({
      'model': _model,
      'max_tokens': _maxTokens,
      'system': catalystSystemPrompt,
      'thinking': {'type': 'adaptive'},
      'output_config': {
        'effort': _effort,
        'format': {
          'type': 'json_schema',
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'required': ['ideas'],
            'properties': {
              'ideas': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'additionalProperties': false,
                  'required': [
                    'conceptName',
                    'paradigmShift',
                    'coreMechanism',
                    'asymmetricAdvantage',
                  ],
                  'properties': {
                    'conceptName': {'type': 'string'},
                    'paradigmShift': {'type': 'string'},
                    'coreMechanism': {'type': 'string'},
                    'asymmetricAdvantage': {'type': 'string'},
                  },
                },
              },
            },
          },
        },
      },
      'messages': [
        {'role': 'user', 'content': trimmedBrief},
      ],
    });

    http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': apiKey.trim(),
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const CatalystException(CatalystError.network,
          'The request timed out. Check your connection and try again.');
    } catch (_) {
      throw const CatalystException(CatalystError.network,
          'Network error. Check your connection and try again.');
    }

    switch (resp.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const CatalystException(CatalystError.unauthorized,
            'API key was rejected. Check it in Settings.');
      case 429:
        throw const CatalystException(CatalystError.rateLimited,
            'Rate limited by Anthropic. Wait a moment and try again.');
      default:
        throw CatalystException(CatalystError.badResponse,
            'Anthropic returned an error (${resp.statusCode}). Try again.');
    }

    return _parse(resp.body, trimmedBrief);
  }

  CatalystResult _parse(String responseBody, String brief) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw const CatalystException(
          CatalystError.badResponse, 'Could not read the response. Try again.');
    }

    if (data['stop_reason'] == 'refusal') {
      throw const CatalystException(CatalystError.refused,
          'The model declined this brief. Try rephrasing it.');
    }

    // Find the first text block (a thinking block may precede it).
    final content = data['content'];
    String? text;
    if (content is List) {
      for (final block in content) {
        if (block is Map && block['type'] == 'text' && block['text'] is String) {
          text = block['text'] as String;
          break;
        }
      }
    }
    if (text == null) {
      throw const CatalystException(
          CatalystError.badResponse, 'Empty response. Try again.');
    }

    // Structured output guarantees `text` is JSON matching our schema.
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const CatalystException(CatalystError.badResponse,
          'Unexpected response format. Try again.');
    }

    final rawIdeas = parsed['ideas'];
    if (rawIdeas is! List) {
      throw const CatalystException(
          CatalystError.badResponse, 'No ideas came back. Try again.');
    }

    final ideas = <CatalystIdea>[];
    for (final e in rawIdeas) {
      if (e is! Map) continue;
      final name = (e['conceptName'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      ideas.add(CatalystIdea(
        id: _uuid.v4(),
        brief: brief,
        conceptName: name,
        paradigmShift: (e['paradigmShift'] as String?)?.trim() ?? '',
        coreMechanism: (e['coreMechanism'] as String?)?.trim() ?? '',
        asymmetricAdvantage:
            (e['asymmetricAdvantage'] as String?)?.trim() ?? '',
        createdAt: DateTime.now(),
      ));
    }

    if (ideas.isEmpty) {
      throw const CatalystException(
          CatalystError.badResponse, 'No usable ideas came back. Try again.');
    }
    return CatalystResult(ideas, CatalystUsage.fromJson(data['usage']));
  }
}

final catalystServiceProvider = Provider<CatalystService>((ref) {
  final service = CatalystService();
  ref.onDispose(() => service._client.close());
  return service;
});
