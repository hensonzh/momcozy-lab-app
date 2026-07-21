import 'package:flutter/widgets.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/privacy/log_redactor.dart';

class MomCozyTelemetryEvent {
  MomCozyTelemetryEvent({
    required this.name,
    required this.timestamp,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) : attributes = Map<String, Object?>.unmodifiable(redactLogMap(attributes));

  final String name;
  final DateTime timestamp;
  final Map<String, Object?> attributes;
}

abstract interface class MomCozyTelemetrySink {
  void record(MomCozyTelemetryEvent event);
}

class NoopMomCozyTelemetrySink implements MomCozyTelemetrySink {
  const NoopMomCozyTelemetrySink();

  @override
  void record(MomCozyTelemetryEvent event) {}
}

class MemoryMomCozyTelemetrySink implements MomCozyTelemetrySink {
  final List<MomCozyTelemetryEvent> events = <MomCozyTelemetryEvent>[];

  @override
  void record(MomCozyTelemetryEvent event) {
    events.add(event);
  }
}

class MomCozyObservability {
  MomCozyObservability({MomCozyTelemetrySink? sink, DateTime Function()? now})
    : _sink = sink ?? const NoopMomCozyTelemetrySink(),
      _now = now ?? DateTime.now;

  final MomCozyTelemetrySink _sink;
  final DateTime Function() _now;

  void recordRouteView(String route, {String source = 'router'}) {
    record('route.view', <String, Object?>{
      'route': _safePath(route),
      'source': source,
    });
  }

  void recordApiRequest({
    required String method,
    required String path,
    required Duration elapsed,
    int? statusCode,
    Object? error,
    bool retryable = false,
  }) {
    final attributes = <String, Object?>{
      'method': method.toUpperCase(),
      'path': _safePath(path),
      'elapsedMs': elapsed.inMilliseconds,
      'retryable': retryable,
    };
    if (statusCode != null) attributes['statusCode'] = statusCode;
    if (error != null) attributes['errorType'] = error.runtimeType.toString();
    record('api.request', attributes);
  }

  void recordAgentStreamLifecycle(
    String phase, {
    String transport = 'unknown',
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    record('agent.stream.$phase', <String, Object?>{
      'transport': transport,
      ...attributes,
    });
  }

  void recordFeatureEvent(
    String feature,
    String action, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    record('feature.event', <String, Object?>{
      'feature': feature,
      'action': action,
      ...attributes,
    });
  }

  void recordNonFatal(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    record(
      'app.non_fatal',
      redactCrashReport(error: error, stackTrace: stackTrace, context: context),
    );
  }

  void record(String name, Map<String, Object?> attributes) {
    _sink.record(
      MomCozyTelemetryEvent(
        name: name,
        timestamp: _now(),
        attributes: attributes,
      ),
    );
  }
}

class ObservedApiJsonTransport
    implements ApiJsonTransport, ApiJsonMutationTransport {
  ObservedApiJsonTransport({required this.inner, required this.observability});

  final ApiJsonTransport inner;
  final MomCozyObservability observability;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    return _record(
      method: 'GET',
      path: path,
      action: () => inner.getJson(path, query: query),
    );
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return _record(
      method: 'POST',
      path: path,
      action: () => inner.postJson(path, body: body, headers: headers),
    );
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return _recordMutation(
      method: 'PUT',
      path: path,
      action: (transport) =>
          transport.putJson(path, body: body, headers: headers),
    );
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return _recordMutation(
      method: 'PATCH',
      path: path,
      action: (transport) =>
          transport.patchJson(path, body: body, headers: headers),
    );
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) {
    return _recordMutation(
      method: 'DELETE',
      path: path,
      successStatusCode: 204,
      action: (transport) => transport.deleteJson(path, headers: headers),
    );
  }

  Future<Map<String, Object?>> _recordMutation({
    required String method,
    required String path,
    int? successStatusCode,
    required Future<Map<String, Object?>> Function(
      ApiJsonMutationTransport transport,
    )
    action,
  }) {
    final transport = inner;
    if (transport is! ApiJsonMutationTransport) {
      throw UnsupportedError('JSON mutation transport is not available.');
    }
    final mutationTransport = transport as ApiJsonMutationTransport;
    return _record(
      method: method,
      path: path,
      successStatusCode: successStatusCode,
      action: () => action(mutationTransport),
    );
  }

  Future<Map<String, Object?>> _record({
    required String method,
    required String path,
    int? successStatusCode,
    required Future<Map<String, Object?>> Function() action,
  }) async {
    final watch = Stopwatch()..start();
    try {
      final response = await action();
      watch.stop();
      observability.recordApiRequest(
        method: method,
        path: path,
        elapsed: watch.elapsed,
        statusCode: _statusCodeFromResponse(response) ?? successStatusCode,
      );
      return response;
    } catch (error) {
      watch.stop();
      observability.recordApiRequest(
        method: method,
        path: path,
        elapsed: watch.elapsed,
        statusCode: _statusCodeFromError(error),
        error: error,
      );
      rethrow;
    }
  }
}

class ObservedApiMultipartTransport implements ApiMultipartTransport {
  ObservedApiMultipartTransport({
    required this.inner,
    required this.observability,
  });

  final ApiMultipartTransport inner;
  final MomCozyObservability observability;

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    final watch = Stopwatch()..start();
    try {
      final response = await inner.uploadMultipart(
        path,
        query: query,
        fields: fields,
        headers: headers,
        file: file,
      );
      watch.stop();
      observability.recordApiRequest(
        method: 'MULTIPART',
        path: path,
        elapsed: watch.elapsed,
        statusCode: _statusCodeFromResponse(response),
      );
      return response;
    } catch (error) {
      watch.stop();
      observability.recordApiRequest(
        method: 'MULTIPART',
        path: path,
        elapsed: watch.elapsed,
        statusCode: _statusCodeFromError(error),
        error: error,
      );
      rethrow;
    }
  }
}

class MomCozyRouteTelemetry extends StatefulWidget {
  const MomCozyRouteTelemetry({
    super.key,
    required this.location,
    required this.observability,
    required this.child,
  });

  final String location;
  final MomCozyObservability observability;
  final Widget child;

  @override
  State<MomCozyRouteTelemetry> createState() => _MomCozyRouteTelemetryState();
}

class _MomCozyRouteTelemetryState extends State<MomCozyRouteTelemetry> {
  String? _lastRecordedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordIfNeeded());
  }

  @override
  void didUpdateWidget(MomCozyRouteTelemetry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recordIfNeeded());
    }
  }

  void _recordIfNeeded() {
    if (!mounted || _lastRecordedLocation == widget.location) return;
    _lastRecordedLocation = widget.location;
    widget.observability.recordRouteView(widget.location);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

int? _statusCodeFromResponse(Map<String, Object?> response) {
  final status = response['status'];
  return status is num && status.isFinite ? status.toInt() : null;
}

int? _statusCodeFromError(Object error) {
  if (error is ApiHttpException) return error.statusCode;
  return null;
}

String _safePath(String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri == null) return rawPath.split('?').first;
  if (uri.hasScheme || uri.hasAuthority) return uri.path;
  return uri.path.isEmpty ? rawPath.split('?').first : uri.path;
}
