sealed class AgentSpecializedArtifactView {
  const AgentSpecializedArtifactView();

  String get title;
}

class AgentBirthPlanCardView extends AgentSpecializedArtifactView {
  const AgentBirthPlanCardView({
    required this.title,
    required this.sections,
    required this.medicalNotes,
    required this.disclaimer,
  });

  @override
  final String title;
  final List<AgentBirthPlanSectionView> sections;
  final List<String> medicalNotes;
  final String disclaimer;
}

class AgentBirthPlanSectionView {
  const AgentBirthPlanSectionView({
    required this.id,
    required this.title,
    required this.values,
  });

  final String id;
  final String title;
  final List<String> values;
}

class AgentHospitalBagCardView extends AgentSpecializedArtifactView {
  const AgentHospitalBagCardView({
    required this.title,
    required this.subtitle,
    required this.groups,
    this.disclaimer,
  });

  @override
  final String title;
  final String subtitle;
  final List<AgentHospitalBagGroupView> groups;
  final String? disclaimer;
}

class AgentHospitalBagGroupView {
  const AgentHospitalBagGroupView({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<AgentHospitalBagItemView> items;
}

class AgentHospitalBagItemView {
  const AgentHospitalBagItemView({
    required this.label,
    this.meta,
    this.priority,
    this.priorityLabel,
    this.description,
    this.personalization,
  });

  final String label;
  final String? meta;
  final String? priority;
  final String? priorityLabel;
  final String? description;
  final String? personalization;
}
