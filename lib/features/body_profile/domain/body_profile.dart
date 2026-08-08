abstract interface class BodyProfileRepository {
  Future<BodyProfile> fetchProfile();

  Future<BodyProfile> saveProfile(BodyProfile profile);
}

enum RecoveryFrequency {
  none,
  rare,
  sometimes,
  often,
  always;

  String get apiValue => name;

  String get label => switch (this) {
    RecoveryFrequency.none => 'None',
    RecoveryFrequency.rare => 'Rare',
    RecoveryFrequency.sometimes => 'Sometimes',
    RecoveryFrequency.often => 'Often',
    RecoveryFrequency.always => 'Always',
  };

  static RecoveryFrequency? tryParse(Object? value) {
    return switch (value) {
      'none' => RecoveryFrequency.none,
      'rare' => RecoveryFrequency.rare,
      'sometimes' => RecoveryFrequency.sometimes,
      'often' => RecoveryFrequency.often,
      'always' => RecoveryFrequency.always,
      _ => null,
    };
  }
}

enum DiastasisSeverity {
  notSure('not_sure', 'Not sure'),
  none('none', 'None'),
  mild('mild', 'Mild'),
  moderate('moderate', 'Moderate'),
  severe('severe', 'Severe');

  const DiastasisSeverity(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static DiastasisSeverity? tryParse(Object? value) {
    for (final severity in values) {
      if (severity.apiValue == value) return severity;
    }
    return null;
  }
}

enum PainZone {
  headNeck('head_neck', 'Head & Neck'),
  upperChest('upper_chest', 'Upper Chest'),
  upperBack('upper_back', 'Upper Back'),
  lowerBack('lower_back', 'Lower Back'),
  lowerAbdomen('lower_abdomen', 'Lower Abdomen'),
  pelvisHips('pelvis_hips', 'Pelvis & Hips'),
  lowerBody('lower_body', 'Lower Body'),
  shouldersNeck('shoulders_neck', 'Shoulders & Neck'),
  other('other', 'Other');

  const PainZone(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PainZone? tryParse(Object? value) {
    for (final zone in values) {
      if (zone.apiValue == value) return zone;
    }
    return null;
  }
}

class BodyPainArea {
  const BodyPainArea({
    required this.zone,
    this.intensity,
    this.sensation = '',
    this.pattern = '',
  });

  final PainZone zone;
  final int? intensity;
  final String sensation;
  final String pattern;
}

class BodyProfile {
  const BodyProfile({
    this.urineLeakage,
    this.lowerAbdominalPain,
    this.pelvicFloorStrength,
    this.diastasisSeverity,
    this.dailyImpactDescription = '',
    this.woundStatus = '',
    this.bleedingStatus = '',
    this.bowelStatus = '',
    this.painAreas = const [],
    this.updatedAt,
    this.hasConfirmedData = false,
  });

  final RecoveryFrequency? urineLeakage;
  final RecoveryFrequency? lowerAbdominalPain;
  final int? pelvicFloorStrength;
  final DiastasisSeverity? diastasisSeverity;
  final String dailyImpactDescription;
  final String woundStatus;
  final String bleedingStatus;
  final String bowelStatus;
  final List<BodyPainArea> painAreas;
  final DateTime? updatedAt;
  final bool hasConfirmedData;

  BodyProfile copyWith({
    RecoveryFrequency? urineLeakage,
    RecoveryFrequency? lowerAbdominalPain,
    int? pelvicFloorStrength,
    DiastasisSeverity? diastasisSeverity,
    String? dailyImpactDescription,
    String? woundStatus,
    String? bleedingStatus,
    String? bowelStatus,
    List<BodyPainArea>? painAreas,
  }) {
    return BodyProfile(
      urineLeakage: urineLeakage ?? this.urineLeakage,
      lowerAbdominalPain: lowerAbdominalPain ?? this.lowerAbdominalPain,
      pelvicFloorStrength: pelvicFloorStrength ?? this.pelvicFloorStrength,
      diastasisSeverity: diastasisSeverity ?? this.diastasisSeverity,
      dailyImpactDescription:
          dailyImpactDescription ?? this.dailyImpactDescription,
      woundStatus: woundStatus ?? this.woundStatus,
      bleedingStatus: bleedingStatus ?? this.bleedingStatus,
      bowelStatus: bowelStatus ?? this.bowelStatus,
      painAreas: painAreas ?? this.painAreas,
      updatedAt: updatedAt,
      hasConfirmedData: true,
    );
  }
}
