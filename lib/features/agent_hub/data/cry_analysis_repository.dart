import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

/// Product Backend owns the classifier result; the Agent receives only its ID.
class CryAnalysisRepository {
  const CryAnalysisRepository({required this.multipart, required this.json});

  final ApiMultipartTransport multipart;
  final ApiJsonTransport json;

  Future<CryAnalysisResult> analyze(
    List<int> wav, {
    required String key,
    required String threadId,
  }) async {
    final response = await multipart.uploadMultipart(
      '/v1/cry-analyses',
      headers: {'Idempotency-Key': key},
      fields: {'thread_id': threadId},
      file: ApiUploadFile(
        name: 'cry.wav',
        mimeType: 'audio/wav',
        sizeBytes: wav.length,
        bytes: wav,
      ),
    );
    return CryAnalysisResult.fromMap(response);
  }

  Future<CryAnalysisResult> readByKey(String key) async =>
      CryAnalysisResult.fromMap(
        await json.getJson(
          '/v1/cry-analyses/by-key/${Uri.encodeComponent(key)}',
        ),
      );

  Future<CryAnalysisResult> read(String id) async => CryAnalysisResult.fromMap(
    await json.getJson('/v1/cry-analyses/${Uri.encodeComponent(id)}'),
  );

  Future<List<CryAnalysisResult>> listForThread(String threadId) async {
    final response = await json.getJson(
      '/v1/cry-analyses',
      query: {'thread_id': threadId},
    );
    final items = response['items'];
    if (items is! List || items.length > 100) {
      throw const FormatException('Invalid cry analysis list');
    }
    return items
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid cry analysis item');
          }
          return CryAnalysisResult.fromMap(Map<String, Object?>.from(item));
        })
        .toList(growable: false);
  }
}

class CryAnalysisResult {
  const CryAnalysisResult({
    required this.id,
    required this.status,
    required this.createdAt,
    this.answer,
  });
  final String id;
  final String status;
  final String? answer;
  final DateTime createdAt;

  factory CryAnalysisResult.fromMap(Map<String, Object?> data) {
    final id = data['id'];
    final status = data['status'];
    final answer = data['answer'];
    final createdAt = data['created_at'];
    final timestamp = createdAt is String ? DateTime.tryParse(createdAt) : null;
    if (id is! String ||
        id.isEmpty ||
        timestamp == null ||
        status is! String ||
        !const {'pending', 'done', 'incomplete', 'failed'}.contains(status) ||
        (status == 'done' &&
            !const {
              'sleep',
              'pain',
              'burp',
              'uncomfortable',
              'hungry',
              'no_cry',
            }.contains(answer)) ||
        (status != 'done' && answer != null)) {
      throw const FormatException('Invalid cry analysis response');
    }
    return CryAnalysisResult(
      id: id,
      status: status,
      answer: answer as String?,
      createdAt: timestamp,
    );
  }
}
