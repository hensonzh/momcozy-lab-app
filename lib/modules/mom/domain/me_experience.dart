enum MeMetric {
  feed('喂奶记录', 'Feed'),
  energy('今天精力', 'Energy'),
  sleep('昨晚睡眠', 'Sleep'),
  mood('今天心情', 'Mood'),
  pump('泵奶记录', 'Pump'),
  pain('喂奶疼痛', 'Pain'),
  latch('含奶情况', 'Latch'),
  bottle('奶瓶喂养', 'Bottle'),
  diaper('尿便记录', 'Diaper'),
  weight('体重记录', 'Weight'),
  storage('储奶记录', 'Storage');

  const MeMetric(this.label, this.artwork);
  final String label, artwork;
}

enum MeIssue {
  comfort('喂奶或泵奶时不舒服', [MeMetric.feed, MeMetric.pump, MeMetric.pain]),
  feeding('宝宝含奶、亲喂或吃奶瓶不顺利', [MeMetric.feed, MeMetric.latch, MeMetric.bottle]),
  intake('担心宝宝没有吃够', [MeMetric.feed, MeMetric.diaper, MeMetric.weight]),
  supply('担心奶量或泵出量偏少', [MeMetric.feed, MeMetric.pump]),
  work('快返工了，想提前安排', [MeMetric.pump, MeMetric.storage, MeMetric.bottle]),
  other('其他困扰 / 暂时说不清', [MeMetric.energy, MeMetric.sleep, MeMetric.mood]);

  const MeIssue(this.label, this.metrics);
  final String label;
  final List<MeMetric> metrics;
}

List<MeMetric> metricsFor(Iterable<MeIssue> issues) =>
    {for (final issue in issues) ...issue.metrics}.toList();

class MeConcern {
  const MeConcern({
    required this.id,
    required this.issues,
    this.note = '',
    this.reminder = true,
    this.ended = false,
  });
  final String id, note;
  final List<MeIssue> issues;
  final bool reminder, ended;
  List<String> get labels => [
    for (final issue in issues)
      issue == MeIssue.other && note.isNotEmpty ? note : issue.label,
  ];
  Map<String, Object?> toJson() => {
    'id': id,
    'issues': issues.map((e) => e.name).toList(),
    'note': note,
    'reminder': reminder,
    'ended': ended,
  };
  factory MeConcern.fromJson(Map<String, Object?> j) => MeConcern(
    id: j['id']! as String,
    issues: (j['issues']! as List)
        .map((e) => MeIssue.values.byName(e as String))
        .toList(),
    note: j['note'] as String? ?? '',
    reminder: j['reminder'] == true,
    ended: j['ended'] == true,
  );
}

class MeObservation {
  const MeObservation({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.value,
    this.fields = const {},
  });
  final String id, value;
  final MeMetric kind;
  final DateTime occurredAt;
  final Map<String, Object?> fields;
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'value': value,
    'fields': fields,
  };
  factory MeObservation.fromJson(Map<String, Object?> j) => MeObservation(
    id: j['id']! as String,
    kind: MeMetric.values.byName(j['kind']! as String),
    occurredAt: DateTime.parse(j['occurred_at']! as String).toLocal(),
    value: j['value']! as String,
    fields: Map<String, Object?>.from(j['fields'] as Map? ?? {}),
  );
}

class MeState {
  const MeState({
    this.profile = const {},
    this.concerns = const [],
    this.order = const [],
    this.records = const [],
    this.failedMetrics = const {},
  });
  final Map<String, Object?> profile;
  final List<MeConcern> concerns;
  final List<MeMetric> order;
  final List<MeObservation> records;
  final Set<MeMetric> failedMetrics;
  List<MeConcern> get active => concerns.where((e) => !e.ended).toList();
  List<MeMetric> get visibleMetrics {
    final visible = <MeMetric>{
      MeMetric.feed,
      MeMetric.energy,
      MeMetric.sleep,
      MeMetric.mood,
      ...metricsFor(active.expand((e) => e.issues)),
    };
    return [
      ...order.where(visible.contains),
      ...visible.where((e) => !order.contains(e)),
    ];
  }

  MeState copyWith({
    Map<String, Object?>? profile,
    List<MeConcern>? concerns,
    List<MeMetric>? order,
    List<MeObservation>? records,
    Set<MeMetric>? failedMetrics,
  }) => MeState(
    profile: profile ?? this.profile,
    concerns: concerns ?? this.concerns,
    order: order ?? this.order,
    records: records ?? this.records,
    failedMetrics: failedMetrics ?? this.failedMetrics,
  );
  factory MeState.fromJson(Map<String, Object?> j) => MeState(
    profile: Map<String, Object?>.from(j['profile'] as Map? ?? {}),
    concerns: [
      for (final e in j['concerns'] as List? ?? [])
        MeConcern.fromJson(Map<String, Object?>.from(e as Map)),
    ],
    order: [
      for (final e in j['order'] as List? ?? [])
        MeMetric.values.byName(e as String),
    ],
    records: [
      for (final e in j['records'] as List? ?? [])
        MeObservation.fromJson(Map<String, Object?>.from(e as Map)),
    ],
  );
}

abstract interface class MeRepository {
  Future<MeState> load(DateTime day);
  Future<Map<String, Object?>> saveProfile(Map<String, Object?> values);
  Future<MeConcern> saveConcern(MeConcern concern);
  Future<List<MeMetric>> saveOrder(List<MeMetric> order);
  Future<MeObservation> saveRecord(MeObservation record);
}
