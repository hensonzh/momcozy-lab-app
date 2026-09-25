enum MeMetric {
  feed('Feeding', 'Feed'),
  energy('Energy today', 'Energy'),
  sleep('Sleep last night', 'Sleep'),
  mood('Mood today', 'Mood'),
  pump('Pumping', 'Pump'),
  pain('Feeding pain', 'Pain'),
  latch('Latch', 'Latch'),
  bottle('Bottle feeding', 'Bottle'),
  diaper('Diapers', 'Diaper'),
  weight('Weight', 'Weight'),
  storage('Stored milk', 'Storage');

  const MeMetric(this.label, this.artwork);
  final String label, artwork;
}

enum MeIssue {
  comfort('Discomfort while nursing or pumping', [
    MeMetric.feed,
    MeMetric.pump,
    MeMetric.pain,
  ]),
  feeding('Feeding or latching has been difficult', [
    MeMetric.feed,
    MeMetric.latch,
    MeMetric.bottle,
  ]),
  intake('Worried my baby is not getting enough', [
    MeMetric.feed,
    MeMetric.diaper,
    MeMetric.weight,
  ]),
  supply('Concerned about my milk supply', [MeMetric.feed, MeMetric.pump]),
  work('Preparing to return to work', [
    MeMetric.pump,
    MeMetric.storage,
    MeMetric.bottle,
  ]),
  other('Something else / Not sure yet', [
    MeMetric.energy,
    MeMetric.sleep,
    MeMetric.mood,
  ]);

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

  // Older observations store selected Chinese choice labels as values. Keep
  // their wire format intact while showing the same choices in English.
  String get displayValue =>
      const <String, String>{
        '有力气': 'Energized',
        '还撑得住': 'Managing',
        '很疲惫': 'Exhausted',
        '少于 3 小时': 'Less than 3 hours',
        '3–4 小时': '3–4 hours',
        '4–5 小时': '4–5 hours',
        '5–6 小时': '5–6 hours',
        '6 小时以上': 'Over 6 hours',
        '不确定': 'Not sure',
        '不太好': 'Having a hard day',
        '一般': 'Okay',
        '不错': 'Good',
        '含得稳': 'Stayed latched',
        '容易松开': 'Came off easily',
        '含不住': 'Could not latch',
        '愿意吃': 'Fed willingly',
        '愿意吃一些': 'Took some',
        '不太愿意': 'Reluctant',
        '不愿意吃': 'Refused',
      }[value] ??
      value;

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
