enum MomLifeStage {
  fertility(
    wireValue: 'fertility',
    label: 'Fertility',
    subtitle: 'Cycle tracking & conception',
  ),
  pregnancy(
    wireValue: 'pregnancy',
    label: 'Pregnancy',
    subtitle: 'Prenatal care & milestones',
  ),
  postpartum(
    wireValue: 'postpartum',
    label: 'Postpartum Recovery',
    subtitle: 'Recovery & lactation',
  );

  const MomLifeStage({
    required this.wireValue,
    required this.label,
    required this.subtitle,
  });

  final String wireValue;
  final String label;
  final String subtitle;

  static MomLifeStage? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'fertility' => MomLifeStage.fertility,
      'pregnancy' || 'prenatal' => MomLifeStage.pregnancy,
      'postpartum' || 'postpartum_recovery' => MomLifeStage.postpartum,
      _ => null,
    };
  }

  static MomLifeStage resolve({
    Object? explicitValue,
    DateTime? expectedDueDate,
    DateTime? actualDeliveryDate,
    bool hasPregnancyDetails = false,
  }) {
    final explicit = tryParse(explicitValue);
    if (explicit != null) return explicit;
    if (actualDeliveryDate != null) return MomLifeStage.postpartum;
    if (expectedDueDate != null) return MomLifeStage.pregnancy;
    if (hasPregnancyDetails) return MomLifeStage.pregnancy;
    return MomLifeStage.postpartum;
  }
}
