import 'dart:typed_data';

enum StoolAnalysisStatus { queued, running, completed, failed, cancelled }

enum StoolAnalysisEventType {
  cardCreated,
  started,
  fieldReady,
  completed,
  failed,
  cancelled,
}

const _colors = {
  'yellow',
  'yellow_brown',
  'brown',
  'green',
  'dark_green',
  'red',
  'black',
  'pale_gray_white',
  'mixed',
  'unknown',
};
const _consistencies = {
  'watery',
  'loose',
  'mushy',
  'formed',
  'hard_pellets',
  'sticky_tarry',
  'unknown',
};
const _risks = {'routine', 'monitor', 'contact_pediatrician', 'urgent'};
const _findings = {
  'seedy',
  'mucus',
  'food_particles',
  'suspected_blood',
  'suspected_pale_acholic_stool',
  'suspected_tarry_black_after_meconium',
  'uncertain',
  'none',
};
const _safetyFindings = {
  'suspected_blood',
  'suspected_pale_acholic_stool',
  'suspected_tarry_black_after_meconium',
};
const _fields = {
  'color',
  'consistency',
  'findings',
  'risk_level',
  'summary',
  'care_advice',
};

class StoolAnalysisResult {
  const StoolAnalysisResult({
    required this.assessmentStatus,
    required this.color,
    required this.consistency,
    required this.findings,
    required this.riskLevel,
    required this.summary,
    required this.careAdvice,
    required this.uncertainties,
    this.ruleVersion,
  });

  final String assessmentStatus;
  final String color;
  final String consistency;
  final List<String> findings;
  final String? riskLevel;
  final String summary;
  final String careAdvice;
  final List<String> uncertainties;
  final String? ruleVersion;

  factory StoolAnalysisResult.fromJson(Map<String, Object?> json) {
    final allowed = {
      'schema_version',
      'rule_version',
      'assessment_status',
      'color',
      'consistency',
      'findings',
      'risk_level',
      'summary',
      'care_advice',
      'uncertainties',
      'photo_observations',
    };
    final findings = _stringList(json['findings']);
    final uncertainties = _stringList(json['uncertainties']);
    final assessment = json['assessment_status'];
    final color = json['color'];
    final consistency = json['consistency'];
    final risk = json['risk_level'];
    final summary = json['summary'];
    final advice = json['care_advice'];
    final ruleVersion = json['rule_version'];
    final observations = json['photo_observations'];
    if (json.keys.toSet().difference(allowed).isNotEmpty ||
        json['schema_version'] != 'stool.result.v1' ||
        (ruleVersion != null &&
            ruleVersion != 'stool.medical.rules.2026-10-23.v1') ||
        (assessment != 'assessed' && assessment != 'unable_to_assess') ||
        color is! String ||
        !_colors.contains(color) ||
        consistency is! String ||
        !_consistencies.contains(consistency) ||
        findings == null ||
        findings.isEmpty ||
        findings.any((item) => !_findings.contains(item)) ||
        (findings.contains('none') && findings.length != 1) ||
        (risk != null && (risk is! String || !_risks.contains(risk))) ||
        summary is! String ||
        summary.isEmpty ||
        summary.length > 500 ||
        advice is! String ||
        advice.isEmpty ||
        advice.length > 800 ||
        uncertainties == null ||
        observations is! List ||
        observations.isEmpty ||
        observations.length > 3 ||
        observations.any((item) => item is! Map<String, dynamic>) ||
        (assessment == 'assessed' && risk == null) ||
        (assessment == 'unable_to_assess' &&
            (risk != null || uncertainties.isEmpty)) ||
        (assessment == 'assessed' &&
            findings.any(_safetyFindings.contains) &&
            risk != 'contact_pediatrician' &&
            risk != 'urgent')) {
      throw const FormatException('Invalid stool analysis result.');
    }
    return StoolAnalysisResult(
      assessmentStatus: assessment as String,
      color: color,
      consistency: consistency,
      findings: List.unmodifiable(findings),
      riskLevel: risk as String?,
      summary: summary,
      careAdvice: advice,
      uncertainties: List.unmodifiable(uncertainties),
      ruleVersion: ruleVersion as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'assessmentStatus': assessmentStatus,
    'color': color,
    'consistency': consistency,
    'findings': findings,
    'riskLevel': riskLevel,
    'summary': summary,
    'careAdvice': careAdvice,
    'uncertainties': uncertainties,
    if (ruleVersion != null) 'ruleVersion': ruleVersion,
  };

  static StoolAnalysisResult? fromMap(Object? value) {
    if (value is! Map) return null;
    final assessment = value['assessmentStatus'];
    final color = value['color'];
    final consistency = value['consistency'];
    final findings = _stringList(value['findings']);
    final risk = value['riskLevel'];
    final summary = value['summary'];
    final advice = value['careAdvice'];
    final uncertainties = _stringList(value['uncertainties']);
    final ruleVersion = value['ruleVersion'];
    if ((assessment != 'assessed' && assessment != 'unable_to_assess') ||
        (ruleVersion != null &&
            ruleVersion != 'stool.medical.rules.2026-10-23.v1') ||
        color is! String ||
        !_colors.contains(color) ||
        consistency is! String ||
        !_consistencies.contains(consistency) ||
        findings == null ||
        findings.isEmpty ||
        findings.any((item) => !_findings.contains(item)) ||
        (findings.contains('none') && findings.length != 1) ||
        (risk != null && (risk is! String || !_risks.contains(risk))) ||
        (assessment == 'assessed' && risk == null) ||
        (assessment == 'unable_to_assess' &&
            (risk != null || uncertainties == null || uncertainties.isEmpty)) ||
        (assessment == 'assessed' &&
            findings.any(_safetyFindings.contains) &&
            risk != 'contact_pediatrician' &&
            risk != 'urgent') ||
        summary is! String ||
        summary.isEmpty ||
        advice is! String ||
        advice.isEmpty ||
        uncertainties == null) {
      return null;
    }
    return StoolAnalysisResult(
      assessmentStatus: assessment as String,
      color: color,
      consistency: consistency,
      findings: List.unmodifiable(findings),
      riskLevel: risk as String?,
      summary: summary,
      careAdvice: advice,
      uncertainties: List.unmodifiable(uncertainties),
      ruleVersion: ruleVersion is String ? ruleVersion : null,
    );
  }
}

List<String>? _stringList(Object? raw) {
  if (raw is! List || raw.any((item) => item is! String)) return null;
  final values = raw.cast<String>();
  if (values.toSet().length != values.length) return null;
  return values;
}

class StoolAnalysisSnapshot {
  const StoolAnalysisSnapshot({
    required this.analysisId,
    required this.status,
    this.result,
  });
  final String analysisId;
  final StoolAnalysisStatus status;
  final StoolAnalysisResult? result;

  factory StoolAnalysisSnapshot.fromJson(Map<String, Object?> json) {
    final id = json['analysis_id'];
    final statuses = StoolAnalysisStatus.values.where(
      (s) => s.name == json['status'],
    );
    final rawResult = json['result'];
    final result = rawResult == null
        ? null
        : rawResult is Map<String, dynamic>
        ? StoolAnalysisResult.fromJson(Map<String, Object?>.from(rawResult))
        : throw const FormatException('Invalid stool result.');
    if (id is! String ||
        id.isEmpty ||
        statuses.length != 1 ||
        (result != null &&
            (statuses.single != StoolAnalysisStatus.completed ||
                json['result_schema_version'] != 'stool.result.v1'))) {
      throw const FormatException('Invalid stool analysis snapshot.');
    }
    return StoolAnalysisSnapshot(
      analysisId: id,
      status: statuses.single,
      result: result,
    );
  }
}

class StoolAnalysisHistoryItem extends StoolAnalysisSnapshot {
  const StoolAnalysisHistoryItem({
    required super.analysisId,
    required super.status,
    required this.babyId,
    required this.createdAt,
    super.result,
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
      result: snapshot.result,
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
    this.field,
    this.value,
    this.result,
  });
  final String analysisId;
  final int sequence;
  final StoolAnalysisEventType type;
  final String? field;
  final Object? value;
  final StoolAnalysisResult? result;

  factory StoolAnalysisEvent.fromJson(Map<String, Object?> json) {
    final allowed = {
      'analysis_id',
      'sequence',
      'schema_version',
      'event_type',
      'payload',
    };
    if (json.keys.toSet().difference(allowed).isNotEmpty ||
        json['schema_version'] != 'stool.events.v1') {
      throw const FormatException('Unsupported stool event contract.');
    }
    final id = json['analysis_id'];
    final sequence = json['sequence'];
    final type = switch (json['event_type']) {
      'stool.card.created' => StoolAnalysisEventType.cardCreated,
      'stool.analysis.started' => StoolAnalysisEventType.started,
      'stool.field.ready' => StoolAnalysisEventType.fieldReady,
      'stool.analysis.completed' => StoolAnalysisEventType.completed,
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
    final rawPayload = json['payload'];
    String? field;
    Object? value;
    StoolAnalysisResult? result;
    if (type == StoolAnalysisEventType.fieldReady) {
      if (rawPayload is! Map<String, dynamic> ||
          rawPayload.keys.toSet().difference({'field', 'value'}).isNotEmpty ||
          rawPayload.keys.length != 2 ||
          rawPayload['field'] is! String ||
          !_fields.contains(rawPayload['field'])) {
        throw const FormatException('Invalid stool field event.');
      }
      field = rawPayload['field'] as String;
      value = rawPayload['value'];
      _validateFieldValue(field, value);
    } else if (type == StoolAnalysisEventType.completed) {
      if (rawPayload is! Map<String, dynamic> ||
          rawPayload.keys.length != 1 ||
          rawPayload['result'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid completed stool event.');
      }
      result = StoolAnalysisResult.fromJson(
        Map<String, Object?>.from(rawPayload['result'] as Map<String, dynamic>),
      );
    } else if (rawPayload != null && type != StoolAnalysisEventType.failed) {
      throw const FormatException('Unexpected stool event payload.');
    }
    return StoolAnalysisEvent(
      analysisId: id,
      sequence: sequence,
      type: type,
      field: field,
      value: value,
      result: result,
    );
  }
}

void _validateFieldValue(String field, Object? value) {
  final valid = switch (field) {
    'color' => value is String && _colors.contains(value),
    'consistency' => value is String && _consistencies.contains(value),
    'findings' =>
      _stringList(value)?.isNotEmpty == true &&
          _stringList(value)!.every(_findings.contains),
    'risk_level' => value == null || value is String && _risks.contains(value),
    'summary' => value is String && value.isNotEmpty && value.length <= 500,
    'care_advice' => value is String && value.isNotEmpty && value.length <= 800,
    _ => false,
  };
  if (!valid) throw const FormatException('Invalid stool field value.');
}

class StoolCardState {
  const StoolCardState({
    required this.analysisId,
    this.sequence = 0,
    this.visible = false,
    this.status = StoolAnalysisStatus.queued,
    this.color,
    this.consistency,
    this.findings,
    this.riskLevel,
    this.summary,
    this.careAdvice,
    this.result,
  });
  final String analysisId;
  final int sequence;
  final bool visible;
  final StoolAnalysisStatus status;
  final String? color;
  final String? consistency;
  final List<String>? findings;
  final String? riskLevel;
  final String? summary;
  final String? careAdvice;
  final StoolAnalysisResult? result;

  Map<String, Object?> toMap() => {
    'analysisId': analysisId,
    'sequence': sequence,
    'visible': visible,
    'status': status.name,
    if (color != null) 'color': color,
    if (consistency != null) 'consistency': consistency,
    if (findings != null) 'findings': findings,
    if (riskLevel != null) 'riskLevel': riskLevel,
    if (summary != null) 'summary': summary,
    if (careAdvice != null) 'careAdvice': careAdvice,
    if (result != null) 'result': result!.toMap(),
  };

  static StoolCardState? fromMap(Object? value) {
    if (value is! Map) return null;
    final id = value['analysisId'];
    final sequence = value['sequence'];
    final visible = value['visible'];
    final statuses = StoolAnalysisStatus.values.where(
      (candidate) => candidate.name == value['status'],
    );
    final result = value['result'] == null
        ? null
        : StoolAnalysisResult.fromMap(value['result']);
    final findings = value['findings'] == null
        ? null
        : _stringList(value['findings']);
    if (id is! String ||
        id.isEmpty ||
        sequence is! int ||
        sequence < 0 ||
        sequence > 9 ||
        statuses.length != 1 ||
        visible is! bool ||
        (sequence == 0 &&
            (visible || statuses.single != StoolAnalysisStatus.queued)) ||
        (sequence > 0 && !visible) ||
        (statuses.single == StoolAnalysisStatus.completed && result == null) ||
        (value['result'] != null && result == null) ||
        (value['findings'] != null && findings == null) ||
        (result != null &&
            ((value['color'] != null && value['color'] != result.color) ||
                (value['consistency'] != null &&
                    value['consistency'] != result.consistency) ||
                (findings != null &&
                    findings.join('|') != result.findings.join('|')) ||
                (value['riskLevel'] != null &&
                    value['riskLevel'] != result.riskLevel) ||
                (value['summary'] != null &&
                    value['summary'] != result.summary) ||
                (value['careAdvice'] != null &&
                    value['careAdvice'] != result.careAdvice)))) {
      return null;
    }
    return StoolCardState(
      analysisId: id,
      sequence: sequence,
      visible: visible,
      status: statuses.single,
      color: value['color'] as String?,
      consistency: value['consistency'] as String?,
      findings: findings == null ? null : List.unmodifiable(findings),
      riskLevel: value['riskLevel'] as String?,
      summary: value['summary'] as String?,
      careAdvice: value['careAdvice'] as String?,
      result: result,
    );
  }

  bool _fieldMatches(String? field, Object? value) => switch (field) {
    'color' => color == value,
    'consistency' => consistency == value,
    'findings' => value is List && findings?.join('|') == value.join('|'),
    'risk_level' => riskLevel == value,
    'summary' => summary == value,
    'care_advice' => careAdvice == value,
    _ => false,
  };

  bool _resultMatches(StoolAnalysisResult other) =>
      result != null &&
      result!.assessmentStatus == other.assessmentStatus &&
      result!.color == other.color &&
      result!.consistency == other.consistency &&
      result!.findings.join('|') == other.findings.join('|') &&
      result!.riskLevel == other.riskLevel &&
      result!.summary == other.summary &&
      result!.careAdvice == other.careAdvice &&
      result!.uncertainties.join('|') == other.uncertainties.join('|');

  StoolCardState apply(StoolAnalysisEvent event) {
    if (event.analysisId != analysisId) {
      throw const FormatException('Wrong analysis event.');
    }
    if (event.sequence < sequence) return this;
    if (event.sequence == sequence) {
      final repeated = switch (event.type) {
        StoolAnalysisEventType.cardCreated =>
          sequence == 1 && status == StoolAnalysisStatus.queued,
        StoolAnalysisEventType.started =>
          sequence == 2 && status == StoolAnalysisStatus.running,
        StoolAnalysisEventType.fieldReady => _fieldMatches(
          event.field,
          event.value,
        ),
        StoolAnalysisEventType.completed =>
          status == StoolAnalysisStatus.completed &&
              event.result != null &&
              _resultMatches(event.result!),
        StoolAnalysisEventType.failed => status == StoolAnalysisStatus.failed,
        StoolAnalysisEventType.cancelled =>
          status == StoolAnalysisStatus.cancelled,
      };
      if (!repeated) {
        throw const FormatException('Conflicting stool event replay.');
      }
      return this;
    }
    if (event.sequence != sequence + 1 ||
        (sequence == 0 && event.type != StoolAnalysisEventType.cardCreated) ||
        (sequence > 0 &&
            (!visible ||
                status == StoolAnalysisStatus.completed ||
                status == StoolAnalysisStatus.failed ||
                status == StoolAnalysisStatus.cancelled)) ||
        (event.type == StoolAnalysisEventType.cardCreated && sequence != 0) ||
        (event.type == StoolAnalysisEventType.started && sequence != 1) ||
        (event.type == StoolAnalysisEventType.fieldReady && sequence < 2) ||
        (event.type == StoolAnalysisEventType.completed &&
            event.result == null)) {
      throw const FormatException('Invalid stool event order.');
    }
    var nextColor = color;
    var nextConsistency = consistency;
    var nextFindings = findings;
    var nextRisk = riskLevel;
    var nextSummary = summary;
    var nextAdvice = careAdvice;
    if (event.type == StoolAnalysisEventType.fieldReady) {
      switch (event.field) {
        case 'color':
          nextColor = event.value! as String;
        case 'consistency':
          nextConsistency = event.value! as String;
        case 'findings':
          nextFindings = List.unmodifiable(
            (event.value! as List).cast<String>(),
          );
        case 'risk_level':
          nextRisk = event.value as String?;
        case 'summary':
          nextSummary = event.value! as String;
        case 'care_advice':
          nextAdvice = event.value! as String;
      }
    }
    final completedResult = event.result;
    if (completedResult != null &&
        ((nextColor != null && nextColor != completedResult.color) ||
            (nextConsistency != null &&
                nextConsistency != completedResult.consistency) ||
            (nextFindings != null &&
                nextFindings.join('|') != completedResult.findings.join('|')) ||
            (nextRisk != null && nextRisk != completedResult.riskLevel) ||
            (nextSummary != null && nextSummary != completedResult.summary) ||
            (nextAdvice != null && nextAdvice != completedResult.careAdvice))) {
      throw const FormatException(
        'Completed result conflicts with streamed fields.',
      );
    }
    return StoolCardState(
      analysisId: analysisId,
      sequence: event.sequence,
      visible: true,
      status: switch (event.type) {
        StoolAnalysisEventType.cardCreated => StoolAnalysisStatus.queued,
        StoolAnalysisEventType.started ||
        StoolAnalysisEventType.fieldReady => StoolAnalysisStatus.running,
        StoolAnalysisEventType.completed => StoolAnalysisStatus.completed,
        StoolAnalysisEventType.failed => StoolAnalysisStatus.failed,
        StoolAnalysisEventType.cancelled => StoolAnalysisStatus.cancelled,
      },
      color: completedResult?.color ?? nextColor,
      consistency: completedResult?.consistency ?? nextConsistency,
      findings: completedResult?.findings ?? nextFindings,
      riskLevel: completedResult?.riskLevel ?? nextRisk,
      summary: completedResult?.summary ?? nextSummary,
      careAdvice: completedResult?.careAdvice ?? nextAdvice,
      result: completedResult ?? result,
    );
  }
}

abstract interface class StoolAnalysisRepository {
  Future<bool> isAnalysisAvailable();
  Future<bool> isFollowupAvailable();
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
