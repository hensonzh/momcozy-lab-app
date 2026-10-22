import 'dart:typed_data';

/// Non-medical transport state; no unvalidated clinical text or fields.
enum StoolAnalysisStatus { queued, running, completed, failed, cancelled }

enum StoolAnalysisEventType { cardCreated, started, failed, cancelled }

class StoolAnalysisSnapshot {
  const StoolAnalysisSnapshot({required this.analysisId, required this.status});
  final String analysisId;
  final StoolAnalysisStatus status;

  factory StoolAnalysisSnapshot.fromJson(Map<String, Object?> json) {
    final id = json['analysis_id'];
    final statuses = StoolAnalysisStatus.values.where(
      (s) => s.name == json['status'],
    );
    if (id is! String || id.isEmpty || statuses.length != 1) {
      throw const FormatException('Invalid stool analysis snapshot.');
    }
    return StoolAnalysisSnapshot(analysisId: id, status: statuses.single);
  }
}

class StoolAnalysisHistoryItem extends StoolAnalysisSnapshot {
  const StoolAnalysisHistoryItem({
    required super.analysisId,
    required super.status,
    required this.babyId,
    required this.createdAt,
  });
  final String babyId;
  final DateTime createdAt;

  factory StoolAnalysisHistoryItem.fromJson(Map<String, Object?> json) {
    final snapshot = StoolAnalysisSnapshot.fromJson(json);
    final babyId = json['baby_id'];
    final createdAt = json['created_at'];
    final parsed = createdAt is String ? DateTime.tryParse(createdAt) : null;
    if (babyId is! String || babyId.isEmpty || parsed == null) {
      throw const FormatException('Invalid stool analysis history item.');
    }
    return StoolAnalysisHistoryItem(
      analysisId: snapshot.analysisId,
      status: snapshot.status,
      babyId: babyId,
      createdAt: parsed,
    );
  }
}

class StoolAnalysisHistoryPage {
  const StoolAnalysisHistoryPage({
    required this.items,
    required this.nextCursor,
  });
  final List<StoolAnalysisHistoryItem> items;
  final String? nextCursor;

  factory StoolAnalysisHistoryPage.fromJson(Map<String, Object?> json) {
    final raw = json['items'];
    final cursor = json['next_cursor'];
    if (raw is! List ||
        raw.any((item) => item is! Map<String, dynamic>) ||
        (cursor != null && (cursor is! String || cursor.isEmpty))) {
      throw const FormatException('Invalid stool analysis history page.');
    }
    final items = raw
        .map(
          (item) => StoolAnalysisHistoryItem.fromJson(
            Map<String, Object?>.from(item as Map<String, dynamic>),
          ),
        )
        .toList(growable: false);
    if (cursor != null && (items.isEmpty || cursor != items.last.analysisId)) {
      throw const FormatException('Invalid stool analysis history cursor.');
    }
    return StoolAnalysisHistoryPage(
      items: items,
      nextCursor: cursor as String?,
    );
  }
}

class StoolAnalysisPhotoRef {
  const StoolAnalysisPhotoRef({required this.photoId, required this.position});
  final String photoId;
  final int position;

  factory StoolAnalysisPhotoRef.fromJson(Map<String, Object?> json) {
    if (json.keys.toSet().difference({'photo_id', 'position'}).isNotEmpty ||
        json['photo_id'] is! String ||
        (json['photo_id'] as String).isEmpty ||
        json['position'] is! int ||
        (json['position'] as int) < 0 ||
        (json['position'] as int) > 2) {
      throw const FormatException('Invalid analysis photo reference.');
    }
    return StoolAnalysisPhotoRef(
      photoId: json['photo_id']! as String,
      position: json['position']! as int,
    );
  }
}

class StoolAnalysisPhotos {
  const StoolAnalysisPhotos({required this.items});
  final List<StoolAnalysisPhotoRef> items;

  factory StoolAnalysisPhotos.fromJson(Map<String, Object?> json) {
    final raw = json['items'];
    if (json.keys.toSet().difference({'items'}).isNotEmpty ||
        raw is! List ||
        raw.isEmpty ||
        raw.length > 3 ||
        raw.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Invalid analysis photos.');
    }
    final items = raw
        .map(
          (item) => StoolAnalysisPhotoRef.fromJson(
            Map<String, Object?>.from(item as Map<String, dynamic>),
          ),
        )
        .toList(growable: false);
    if (items.map((item) => item.position).toList().join(',') !=
            List.generate(items.length, (index) => index).join(',') ||
        items.map((item) => item.photoId).toSet().length != items.length) {
      throw const FormatException('Invalid analysis photo order.');
    }
    return StoolAnalysisPhotos(items: items);
  }
}

class StoolAnalysisEvent {
  const StoolAnalysisEvent({
    required this.analysisId,
    required this.sequence,
    required this.type,
  });
  final String analysisId;
  final int sequence;
  final StoolAnalysisEventType type;

  factory StoolAnalysisEvent.fromJson(Map<String, Object?> json) {
    if (json.keys.toSet().difference({
          'analysis_id',
          'sequence',
          'schema_version',
          'event_type',
        }).isNotEmpty ||
        json['schema_version'] != 'stool.events.v1') {
      throw const FormatException('Unsupported stool event contract.');
    }
    final id = json['analysis_id'];
    final sequence = json['sequence'];
    final type = switch (json['event_type']) {
      'stool.card.created' => StoolAnalysisEventType.cardCreated,
      'stool.analysis.started' => StoolAnalysisEventType.started,
      'stool.analysis.failed' => StoolAnalysisEventType.failed,
      'stool.analysis.cancelled' => StoolAnalysisEventType.cancelled,
      _ => null,
    };
    if (id is! String ||
        id.isEmpty ||
        sequence is! int ||
        sequence < 1 ||
        type == null) {
      throw const FormatException('Invalid stool event.');
    }
    return StoolAnalysisEvent(analysisId: id, sequence: sequence, type: type);
  }
}

/// Reducer for persisted cursor/state; gaps and unsupported events fail closed.
class StoolCardState {
  const StoolCardState({
    required this.analysisId,
    this.sequence = 0,
    this.visible = false,
    this.status = StoolAnalysisStatus.queued,
  });
  final String analysisId;
  final int sequence;
  final bool visible;
  final StoolAnalysisStatus status;

  Map<String, Object?> toMap() => {
    'analysisId': analysisId,
    'sequence': sequence,
    'visible': visible,
    'status': status.name,
  };

  static StoolCardState? fromMap(Object? value) {
    if (value is! Map) return null;
    final id = value['analysisId'];
    final sequence = value['sequence'];
    final visible = value['visible'];
    final statuses = StoolAnalysisStatus.values.where(
      (candidate) => candidate.name == value['status'],
    );
    if (id is! String ||
        id.isEmpty ||
        sequence is! int ||
        statuses.length != 1 ||
        visible is! bool ||
        (sequence == 0 &&
            (visible || statuses.single != StoolAnalysisStatus.queued)) ||
        (sequence == 1 &&
            (!visible || statuses.single != StoolAnalysisStatus.queued)) ||
        (sequence == 2 &&
            (!visible ||
                (statuses.single != StoolAnalysisStatus.running &&
                    statuses.single != StoolAnalysisStatus.failed &&
                    statuses.single != StoolAnalysisStatus.cancelled))) ||
        (sequence == 3 &&
            (!visible ||
                (statuses.single != StoolAnalysisStatus.failed &&
                    statuses.single != StoolAnalysisStatus.cancelled))) ||
        sequence < 0 ||
        sequence > 3) {
      return null;
    }
    return StoolCardState(
      analysisId: id,
      sequence: sequence,
      visible: visible,
      status: statuses.single,
    );
  }

  StoolCardState apply(StoolAnalysisEvent event) {
    if (event.analysisId != analysisId) {
      throw const FormatException('Wrong analysis event.');
    }
    if (event.sequence == sequence) {
      final repeated = switch (event.type) {
        StoolAnalysisEventType.cardCreated =>
          sequence == 1 && status == StoolAnalysisStatus.queued,
        StoolAnalysisEventType.started =>
          sequence == 2 && status == StoolAnalysisStatus.running,
        StoolAnalysisEventType.failed => status == StoolAnalysisStatus.failed,
        StoolAnalysisEventType.cancelled =>
          status == StoolAnalysisStatus.cancelled,
      };
      if (!repeated) {
        throw const FormatException('Conflicting stool event replay.');
      }
      return this;
    }
    if (event.sequence < sequence) return this;
    if (event.sequence != sequence + 1 ||
        (sequence == 0 && event.type != StoolAnalysisEventType.cardCreated) ||
        (sequence > 0 &&
            (!visible ||
                status == StoolAnalysisStatus.failed ||
                status == StoolAnalysisStatus.cancelled ||
                event.type == StoolAnalysisEventType.cardCreated ||
                (event.type == StoolAnalysisEventType.started &&
                    (sequence != 1 || status != StoolAnalysisStatus.queued)) ||
                (sequence == 2 && status != StoolAnalysisStatus.running)))) {
      throw const FormatException('Invalid stool event order.');
    }
    return StoolCardState(
      analysisId: analysisId,
      sequence: event.sequence,
      visible: true,
      status: switch (event.type) {
        StoolAnalysisEventType.cardCreated => StoolAnalysisStatus.queued,
        StoolAnalysisEventType.started => StoolAnalysisStatus.running,
        StoolAnalysisEventType.failed => StoolAnalysisStatus.failed,
        StoolAnalysisEventType.cancelled => StoolAnalysisStatus.cancelled,
      },
    );
  }
}

abstract interface class StoolAnalysisRepository {
  Future<bool> isAnalysisAvailable();
  Future<StoolAnalysisSnapshot> submit({
    required String babyId,
    required String threadId,
    required List<String> photoIds,
    required String idempotencyKey,
  });
  Future<StoolAnalysisSnapshot> getStatus(String analysisId);
  Future<void> deleteAnalysis(String analysisId);
  Future<StoolAnalysisPhotos> listPhotos(String analysisId);
  Future<Uint8List> loadThumbnail(String analysisId, String photoId);
  Future<StoolAnalysisHistoryPage> listForThread({
    required String threadId,
    String? cursor,
    int limit,
  });
  Stream<StoolAnalysisEvent> eventsAfter(String analysisId, int afterSequence);
}
