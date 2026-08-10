import 'dart:convert';
import 'dart:io';

import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/network/transport_security_policy.dart';

class MotionVoiceSignalingAnswer {
  const MotionVoiceSignalingAnswer({
    required this.answerSdp,
    required this.provider,
    required this.sessionId,
    required this.visualContextEnabled,
  });

  final String answerSdp;
  final String provider;
  final String sessionId;
  final bool visualContextEnabled;
}

class MotionVoiceSignaling {
  MotionVoiceSignaling({
    required Uri baseUri,
    required this.tokenProvider,
    this.onUnauthorized,
    HttpClient? httpClient,
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       _httpClient = httpClient ?? HttpClient();

  final Uri baseUri;
  final String? Function() tokenProvider;
  final Future<bool> Function()? onUnauthorized;
  final HttpClient _httpClient;

  Future<MotionVoiceSignalingAnswer> createAnswer({
    required String assessmentId,
    required String offerSdp,
  }) async {
    var response = await _post(assessmentId: assessmentId, offerSdp: offerSdp);
    if (response.statusCode == HttpStatus.unauthorized &&
        onUnauthorized != null &&
        await onUnauthorized!()) {
      response = await _post(assessmentId: assessmentId, offerSdp: offerSdp);
    }
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, Object?>? decoded;
      try {
        final value = jsonDecode(body);
        if (value is Map) decoded = Map<String, Object?>.from(value);
      } on FormatException {
        decoded = null;
      }
      throw ApiHttpException(
        statusCode: response.statusCode,
        statusText: response.reasonPhrase,
        body: decoded,
      );
    }
    if (!body.trimLeft().startsWith('v=0')) {
      throw const FormatException('Realtime voice returned invalid SDP.');
    }
    return MotionVoiceSignalingAnswer(
      answerSdp: body,
      provider:
          response.headers.value('X-MomCozy-Motion-Voice-Provider')?.trim() ??
          '',
      sessionId:
          response.headers.value('X-MomCozy-Motion-Voice-Session')?.trim() ??
          '',
      visualContextEnabled: motionVisualContextEnabledFromHeader(
        response.headers.value('X-MomCozy-Motion-Visual-Context'),
      ),
    );
  }

  Future<HttpClientResponse> _post({
    required String assessmentId,
    required String offerSdp,
  }) async {
    final request = await _httpClient.postUrl(
      _resolve('/v1/motion-assessments/$assessmentId/voice-sessions'),
    );
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/sdp')
      ..set(HttpHeaders.contentTypeHeader, 'application/sdp')
      ..set('X-Momcozy-Client', 'flutter-motion-assessment');
    final token = tokenProvider()?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    request.add(utf8.encode(offerSdp));
    return request.close().timeout(const Duration(seconds: 25));
  }

  Uri _resolve(String path) {
    final root = baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/';
    return baseUri.replace(
      path: '$root${path.startsWith('/') ? path.substring(1) : path}',
      queryParameters: baseUri.queryParameters.isEmpty
          ? null
          : baseUri.queryParameters,
    );
  }
}

bool motionVisualContextEnabledFromHeader(String? value) {
  return value?.trim().toLowerCase() == 'enabled';
}
