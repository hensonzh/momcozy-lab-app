sealed class AgentSpecializedArtifactView {
  const AgentSpecializedArtifactView();

  String get title;
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
