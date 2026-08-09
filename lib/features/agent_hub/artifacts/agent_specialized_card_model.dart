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

class AgentIbclcConsultCardView extends AgentSpecializedArtifactView {
  const AgentIbclcConsultCardView({
    required this.title,
    required this.consultId,
    required this.sourceArtifactId,
    required this.consultantName,
    required this.consultantCredentials,
    required this.chatLabel,
    required this.chatNote,
    this.consultantExperience,
    this.consultantBio,
    this.reason,
    this.feedingContext,
    this.urgency = 'routine',
    this.preferredLanguage,
  });

  @override
  final String title;
  final String consultId;
  final String sourceArtifactId;
  final String consultantName;
  final String consultantCredentials;
  final String? consultantExperience;
  final String? consultantBio;
  final String chatLabel;
  final String chatNote;
  final String? reason;
  final String? feedingContext;
  final String urgency;
  final String? preferredLanguage;
}

class AgentMotionAssessmentCardView extends AgentSpecializedArtifactView {
  const AgentMotionAssessmentCardView({
    required this.title,
    required this.target,
    required this.sourceArtifactId,
    required this.description,
    required this.startLabel,
    required this.routeLocation,
    required this.videoUploadEnabled,
    required this.landmarkUploadEnabled,
    required this.disclaimer,
    this.userGoal,
  });

  @override
  final String title;
  final String target;
  final String sourceArtifactId;
  final String? userGoal;
  final String description;
  final String startLabel;
  final String routeLocation;
  final bool videoUploadEnabled;
  final bool landmarkUploadEnabled;
  final String disclaimer;
}
