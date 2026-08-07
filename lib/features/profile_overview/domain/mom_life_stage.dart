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
    DateTime? deliveryDate,
    bool hasPregnancyDetails = false,
    DateTime Function()? now,
  }) {
    final explicit = tryParse(explicitValue);
    if (explicit != null) return explicit;
    if (deliveryDate != null) {
      final value = (now ?? DateTime.now)();
      final today = DateTime(value.year, value.month, value.day);
      return deliveryDate.isAfter(today)
          ? MomLifeStage.pregnancy
          : MomLifeStage.postpartum;
    }
    if (hasPregnancyDetails) return MomLifeStage.pregnancy;
    return MomLifeStage.postpartum;
  }
}
