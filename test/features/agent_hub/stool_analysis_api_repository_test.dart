import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/stool_analysis_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/stool_analysis.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';

void main() {
  final analysis = '123e4567-e89b-12d3-a456-426614174000';
  final baby = '123e4567-e89b-12d3-a456-426614174001';
  final thread = '123e4567-e89b-12d3-a456-426614174002';
  final photo = '123e4567-e89b-12d3-a456-426614174003';

  test(
    'capability, dedicated submit and status are typed and owner-owned',
    () async {
      final json = _Json()..analysisId = analysis;
      final sse = _Sse();
      final repository = StoolAnalysisApiRepository(
        jsonTransport: json,
        streamConnector: sse,
        apiBaseUri: Uri.parse('https://product.test/'),
        accessTokenProvider: () => 'token',
      );
      expect(await repository.isAnalysisAvailable(), isFalse);
      expect(json.getPath, '/v1/stool-photos/capability');
      final created = await repository.submit(
        babyId: baby,
        threadId: thread,
        photoIds: [photo],
        idempotencyKey: 'analysis-once',
      );
      expect(created.analysisId, analysis);
      expect(created.status, StoolAnalysisStatus.queued);
      expect(json.postPath, stoolAnalysisEndpoint);
      expect(json.headers, {
        'Idempotency-Key': 'analysis-once',
        'Accept-Language': 'en',
      });
      expect(json.body, {
        'baby_id': baby,
        'thread_id': thread,
        'photo_ids': [photo],
      });
      expect((await repository.getStatus(analysis)).analysisId, analysis);
      expect(json.getPath, '/v1/stool-analyses/$analysis');
      await expectLater(
        repository.submit(
          babyId: baby,
          threadId: thread,
          photoIds: [photo, photo],
          idempotencyKey: 'bad',
        ),
        throwsFormatException,
      );
      expect(json.postCalls, 1);
    },
  );

  test(
    'submit sends the selected supported language, never a market header',
    () async {
      final json = _Json()..analysisId = analysis;
      var locale = 'zh-CN';
      final repository = StoolAnalysisApiRepository(
        jsonTransport: json,
        streamConnector: _Sse(),
        apiBaseUri: Uri.parse('https://product.test/'),
        accessTokenProvider: () => 'token',
        languageProvider: () => locale,
      );
      await repository.submit(
        babyId: baby,
        threadId: thread,
        photoIds: [photo],
        idempotencyKey: 'localized',
      );
      expect(json.headers, {
        'Idempotency-Key': 'localized',
        'Accept-Language': 'zh',
      });
      locale = 'fr-FR';
      await expectLater(
        repository.submit(
          babyId: baby,
          threadId: thread,
          photoIds: [photo],
          idempotencyKey: 'unsupported',
        ),
        throwsFormatException,
      );
      expect(json.postCalls, 1);
    },
  );

  test(
    'ordered progress is read from the Product cursor without medical fields',
    () async {
      final json = _Json()..analysisId = analysis;
      final sse = _Sse()
        ..frames = [
          _frame(analysis, 2, 'stool.analysis.started'),
          _frame(analysis, 3, 'stool.analysis.failed'),
        ];
      final repository = StoolAnalysisApiRepository(
        jsonTransport: json,
        streamConnector: sse,
        apiBaseUri: Uri.parse('https://product.test/'),
        accessTokenProvider: () => 'token',
      );
      final events = await repository.eventsAfter(analysis, 1).toList();
      expect(events.map((event) => event.type), [
        StoolAnalysisEventType.started,
        StoolAnalysisEventType.failed,
      ]);
      expect(sse.uri.queryParameters['after_sequence'], '1');
    },
  );

  test('finite SSE page binds event type, cursor, ID and bearer token', () async {
    final json = _Json()..analysisId = analysis;
    final sse = _Sse()..frames = [_frame(analysis, 1, 'stool.card.created')];
    final repository = StoolAnalysisApiRepository(
      jsonTransport: json,
      streamConnector: sse,
      apiBaseUri: Uri.parse('https://product.test/api/'),
      accessTokenProvider: () => 'token',
    );
    final events = await repository.eventsAfter(analysis, 0).toList();
    expect(events.single.type, StoolAnalysisEventType.cardCreated);
    expect(
      sse.uri.toString(),
      'https://product.test/api/v1/stool-analyses/$analysis/events/stream?after_sequence=0',
    );
    expect(sse.headers, {
      'Authorization': 'Bearer token',
      'Accept': 'text/event-stream',
    });
    sse.frames = [];
    expect(
      await repository.eventsAfter(analysis, events.single.sequence).toList(),
      isEmpty,
    );
    expect(sse.uri.queryParameters['after_sequence'], '1');
  });

  test(
    'SSE refreshes bearer once on 401 and never puts token in URL',
    () async {
      final json = _Json()..analysisId = analysis;
      final sse = _Sse()
        ..failOnceStatus = 401
        ..frames = [_frame(analysis, 1, 'stool.card.created')];
      var token = 'expired';
      var refreshes = 0;
      final repository = StoolAnalysisApiRepository(
        jsonTransport: json,
        streamConnector: sse,
        apiBaseUri: Uri.parse('https://product.test/'),
        accessTokenProvider: () => token,
        onUnauthorized: () async {
          refreshes++;
          token = 'rotated';
          return true;
        },
      );
      final events = await repository.eventsAfter(analysis, 0).toList();
      expect(events.single.type, StoolAnalysisEventType.cardCreated);
      expect(refreshes, 1);
      expect(sse.calls, 2);
      expect(sse.tokens, ['Bearer expired', 'Bearer rotated']);
      expect(sse.uri.toString(), isNot(contains('rotated')));
      sse.failOnceStatus = 403;
      sse.calls = 0;
      await expectLater(
        repository.eventsAfter(analysis, 0).toList(),
        throwsA(isA<AgentStreamTransportException>()),
      );
      expect(refreshes, 1);
    },
  );

  test(
    'private thumbnail refs and bounded JPEG are bearer-only and retry once',
    () async {
      final json = _Json()..analysisId = analysis;
      final binary = _Thumbnail()..unauthorizedOnce = true;
      var token = 'old';
      var refreshes = 0;
      final repository = StoolAnalysisApiRepository(
        jsonTransport: json,
        streamConnector: _Sse(),
        thumbnailConnector: binary,
        apiBaseUri: Uri.parse('https://product.test/'),
        accessTokenProvider: () => token,
        onUnauthorized: () async {
          refreshes++;
          token = 'new';
          return true;
        },
      );
      final refs = await repository.listPhotos(analysis);
      expect(refs.items.single.photoId, photo);
      expect(refs.items.single.position, 0);
      final bytes = await repository.loadThumbnail(analysis, photo);
      expect(bytes, binary.jpeg);
      expect(refreshes, 1);
      expect(binary.calls, 2);
      expect(binary.tokens, ['Bearer old', 'Bearer new']);
      expect(
        binary.uri.toString(),
        'https://product.test/v1/stool-analyses/$analysis/photos/$photo/thumbnail',
      );
      expect(binary.uri.toString(), isNot(contains('new')));
      binary.contentType = 'text/html';
      await expectLater(
        repository.loadThumbnail(analysis, photo),
        throwsFormatException,
      );
      json.photoResponse = {
        'items': [
          {'photo_id': photo, 'position': 1},
        ],
      };
      await expectLater(repository.listPhotos(analysis), throwsFormatException);
    },
  );

  test(
    'explicit deletion uses owner-authenticated mutation and never inferred availability',
    () async {
      final deletion = _Delete();
      final repository = StoolAnalysisApiRepository(
        jsonTransport: _Json(),
        streamConnector: _Sse(),
        deleteTransport: deletion,
        apiBaseUri: Uri.parse('https://product.test/'),
        accessTokenProvider: () => 'token',
      );
      await repository.deleteAnalysis(analysis);
      expect(deletion.path, '/v1/stool-analyses/$analysis');
      await expectLater(repository.deleteAnalysis(''), throwsFormatException);
      expect(deletion.calls, 1);
    },
  );

  test(
    'owner-scoped thread history pages restore typed nonmedical state',
    () async {
      final json = _Json()..analysisId = analysis;
      final repository = StoolAnalysisApiRepository(
        jsonTransport: json,
        streamConnector: _Sse(),
        apiBaseUri: Uri.parse('https://product.test/'),
        accessTokenProvider: () => 'token',
      );
      json.historyResponse = {
        'items': [
          {
            'analysis_id': analysis,
            'baby_id': baby,
            'status': 'queued',
            'created_at': '2026-10-22T00:00:00Z',
          },
        ],
        'next_cursor': analysis,
      };
      final page = await repository.listForThread(threadId: thread, limit: 1);
      expect(json.getPath, stoolAnalysisEndpoint);
      expect(json.getQuery, {'thread_id': thread, 'limit': 1});
      expect(page.items.single.babyId, baby);
      expect(page.nextCursor, analysis);
      await repository.listForThread(threadId: thread, cursor: analysis);
      expect(json.getQuery, {
        'thread_id': thread,
        'limit': 50,
        'cursor': analysis,
      });
      json.historyResponse = {'items': [], 'next_cursor': analysis};
      await expectLater(
        repository.listForThread(threadId: thread),
        throwsFormatException,
      );
      json.historyResponse = {
        'items': [
          {
            'analysis_id': analysis,
            'baby_id': baby,
            'status': 'unvalidated',
            'created_at': '2026-10-22T00:00:00Z',
          },
        ],
        'next_cursor': null,
      };
      await expectLater(
        repository.listForThread(threadId: thread),
        throwsFormatException,
      );
    },
  );

  test(
    'unknown medical fields, cursor tampering and wrong owner ID fail closed',
    () async {
      final json = _Json()..analysisId = analysis;
      final sse = _Sse();
      final repository = StoolAnalysisApiRepository(
        jsonTransport: json,
        streamConnector: sse,
        apiBaseUri: Uri.parse('https://product.test/'),
        accessTokenProvider: () => 'token',
      );
      sse.frames = [
        _frame(analysis, 1, 'stool.card.created', extra: {'risk': 'low'}),
      ];
      await expectLater(
        repository.eventsAfter(analysis, 0).toList(),
        throwsFormatException,
      );
      sse.frames = [_frame(analysis, 2, 'stool.card.created', id: '3')];
      await expectLater(
        repository.eventsAfter(analysis, 1).toList(),
        throwsFormatException,
      );
      sse.frames = [_frame('different', 1, 'stool.card.created')];
      await expectLater(
        repository.eventsAfter(analysis, 0).toList(),
        throwsFormatException,
      );
      sse.frames = [_frame(analysis, 1, 'stool.field.updated')];
      await expectLater(
        repository.eventsAfter(analysis, 0).toList(),
        throwsFormatException,
      );
      json.analysisId = 'different';
      await expectLater(repository.getStatus(analysis), throwsFormatException);
    },
  );

  test(
    'card shell precedes terminal; replay harmless, gap and terminal conflicts fail',
    () {
      final start = StoolCardState(analysisId: analysis);
      final created = StoolAnalysisEvent.fromJson(
        _event(analysis, 1, 'stool.card.created'),
      );
      final first = start.apply(created);
      expect(first.visible, isTrue);
      expect(first.sequence, 1);
      expect(first.status, StoolAnalysisStatus.queued);
      expect(StoolCardState.fromMap(first.toMap())?.sequence, 1);
      expect(
        StoolCardState.fromMap({
          'analysisId': analysis,
          'sequence': 1,
          'visible': true,
          'status': 'completed',
        }),
        isNull,
      );
      expect(identical(first.apply(created), first), isTrue);
      expect(
        () => first.apply(
          const StoolAnalysisEvent(
            analysisId: '123e4567-e89b-12d3-a456-426614174000',
            sequence: 1,
            type: StoolAnalysisEventType.failed,
          ),
        ),
        throwsFormatException,
      );
      final failed = first.apply(
        StoolAnalysisEvent.fromJson(
          _event(analysis, 2, 'stool.analysis.failed'),
        ),
      );
      expect(failed.status, StoolAnalysisStatus.failed);
      expect(
        () => failed.apply(
          StoolAnalysisEvent.fromJson(
            _event(analysis, 3, 'stool.analysis.cancelled'),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => start.apply(
          StoolAnalysisEvent.fromJson(
            _event(analysis, 2, 'stool.analysis.failed'),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => first.apply(
          StoolAnalysisEvent.fromJson(
            _event('different', 2, 'stool.analysis.failed'),
          ),
        ),
        throwsFormatException,
      );
    },
  );
}

Map<String, Object?> _event(
  String analysis,
  int sequence,
  String type, {
  Map<String, Object?> extra = const {},
}) => {
  'analysis_id': analysis,
  'sequence': sequence,
  'schema_version': 'stool.events.v1',
  'event_type': type,
  ...extra,
};
String _frame(
  String analysis,
  int sequence,
  String type, {
  String? id,
  Map<String, Object?> extra = const {},
}) =>
    'id: ${id ?? sequence}\nevent: $type\ndata: ${jsonEncode(_event(analysis, sequence, type, extra: extra))}\n\n';

class _Json implements ApiJsonTransport {
  String? getPath;
  Map<String, Object?>? getQuery;
  Map<String, Object?>? historyResponse;
  Map<String, Object?>? photoResponse;
  String? postPath;
  String? analysisId;
  int postCalls = 0;
  Map<String, Object?>? body;
  Map<String, String>? headers;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    getPath = path;
    getQuery = query;
    if (path == stoolAnalysisEndpoint) {
      return historyResponse ?? {'items': [], 'next_cursor': null};
    }
    if (path.endsWith('/photos')) {
      return photoResponse ??
          {
            'items': [
              {
                'photo_id': '123e4567-e89b-12d3-a456-426614174003',
                'position': 0,
              },
            ],
          };
    }
    return path.endsWith('/capability')
        ? {'analysis_available': false}
        : {'analysis_id': analysisId, 'status': 'queued'};
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    postCalls++;
    postPath = path;
    this.body = body;
    this.headers = headers;
    return {'analysis_id': analysisId, 'status': 'queued'};
  }
}

class _Sse implements AgentStreamSseGetConnector {
  late Uri uri;
  late Map<String, String> headers;
  List<String> frames = [];
  int? failOnceStatus;
  int calls = 0;
  final tokens = <String>[];
  @override
  Stream<String> get(Uri uri, {required Map<String, String> headers}) async* {
    this.uri = uri;
    this.headers = headers;
    calls++;
    tokens.add(headers['Authorization'] ?? '');
    if (calls == 1 && failOnceStatus != null) {
      throw AgentStreamTransportException(
        'Unauthorized.',
        statusCode: failOnceStatus,
      );
    }
    yield* Stream.fromIterable(frames);
  }
}

class _Thumbnail implements ProductAssetHttpConnector {
  bool unauthorizedOnce = false;
  int calls = 0;
  String contentType = 'image/jpeg';
  final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
  final tokens = <String>[];
  late Uri uri;
  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    this.uri = uri;
    calls++;
    tokens.add(headers['Authorization'] ?? '');
    return ProductAssetHttpResponse(
      statusCode: unauthorizedOnce && calls == 1 ? 401 : 200,
      statusText: 'OK',
      contentType: contentType,
      body: jpeg,
    );
  }
}

class _Delete implements ApiJsonMutationTransport {
  String? path;
  int calls = 0;
  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    this.path = path;
    calls++;
    return {};
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
}
