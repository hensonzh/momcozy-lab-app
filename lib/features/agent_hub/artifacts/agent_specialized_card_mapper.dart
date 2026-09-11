import 'dart:convert';

import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';

AgentSpecializedArtifactView? mapAgentSpecializedCard({
  required AgentArtifactPresentationKind presentationKind,
  required Map<String, Object?> cardJson,
  Map<String, Object?> payload = const <String, Object?>{},
  String artifactId = '',
  String consultIdFallbackArtifactId = '',
}) {
  return switch (presentationKind) {
    AgentArtifactPresentationKind.ibclcConsultCard => _ibclcConsultCard(
      cardJson.isNotEmpty ? cardJson : payload,
      artifactId,
      consultIdFallbackArtifactId,
    ),
    AgentArtifactPresentationKind.motionAssessmentCard => _motionAssessmentCard(
      cardJson.isNotEmpty ? cardJson : payload,
      artifactId,
    ),
    _ => null,
  };
}

AgentMotionAssessmentCardView? _motionAssessmentCard(
  Map<String, Object?> raw,
  String artifactId,
) {
  final nestedPayload = _map(raw['payload']);
  final source = <String, Object?>{...nestedPayload, ...raw};
  final privacy = _map(source['privacy']);
  final target = _text(source['target']);
  if (target != 'forward_head' && target != 'posture_screen') return null;
  final isPostureScreen = target == 'posture_screen';
  final normalizedArtifactId = artifactId.trim();
  final routeLocation = Uri(
    path: '/motion-assessment',
    queryParameters: {
      'target': target,
      if (normalizedArtifactId.isNotEmpty)
        'source_artifact_id': normalizedArtifactId,
    },
  ).toString();
  return AgentMotionAssessmentCardView(
    title: isPostureScreen ? '体态动态评估' : '头颈姿态动态评估',
    target: target,
    sourceArtifactId: normalizedArtifactId,
    userGoal: _nonEmptyText(source['user_goal'] ?? source['userGoal']),
    description: _text(source['description']).isEmpty
        ? isPostureScreen
              ? '先用语音选择评估项目，再按 CozyMate 的提示完成取景。'
              : '按语音提示调整站位，系统会实时检查头颈取景质量。'
        : _text(source['description']),
    startLabel: '开始评估',
    routeLocation: routeLocation,
    videoUploadEnabled:
        privacy['video_upload_enabled'] == true ||
        privacy['videoUploadEnabled'] == true,
    landmarkUploadEnabled:
        privacy['landmark_upload_enabled'] == true ||
        privacy['landmarkUploadEnabled'] == true,
    disclaimer: _text(source['disclaimer']).isEmpty
        ? '结果只反映当前画面，不替代医疗诊断。'
        : _text(source['disclaimer']),
  );
}

AgentIbclcConsultCardView _ibclcConsultCard(
  Map<String, Object?> raw,
  String artifactId,
  String consultIdFallbackArtifactId,
) {
  final nestedPayload = _map(raw['payload']);
  final source = <String, Object?>{...nestedPayload, ...raw};
  final consultant = _map(source['consultant']);
  final chat = _map(source['chat']);
  final explicitConsultId = _firstText(source, const [
    'consult_id',
    'consultId',
  ]);
  final consultId = explicitConsultId.isNotEmpty
      ? explicitConsultId
      : consultIdFallbackArtifactId.trim().isNotEmpty
      ? consultIdFallbackArtifactId.trim()
      : _stableIbclcConsultId(jsonEncode(source));
  final rawBio = _text(consultant['bio']);
  final consultantBio = rawBio
      .replaceFirst(RegExp(r'^(?:IBCLC\s*)?国际认证[哺泌]乳顾问[，,、。\s]*'), '')
      .trim();
  return AgentIbclcConsultCardView(
    title: _text(source['title']).isEmpty
        ? 'IBCLC 在线咨询'
        : _text(source['title']),
    consultId: consultId,
    sourceArtifactId: artifactId,
    consultantName: _text(consultant['name']).isEmpty
        ? 'IBCLC 顾问'
        : _text(consultant['name']),
    consultantCredentials: _text(consultant['credentials']).isEmpty
        ? 'IBCLC 国际认证哺乳顾问'
        : _text(consultant['credentials']),
    consultantExperience: _nonEmptyText(consultant['experience']),
    consultantBio: _nullIfEmpty(consultantBio),
    chatLabel: _text(chat['label']).isEmpty ? '咨询 IBCLC' : _text(chat['label']),
    chatNote: _text(chat['note']).isEmpty
        ? '启动咨询后，会自动将你的问题同步给顾问'
        : _text(chat['note']),
    reason: _nonEmptyText(source['reason']),
    feedingContext: _nonEmptyText(
      source['feeding_context'] ?? source['feedingContext'],
    ),
    urgency: _text(source['urgency']).isEmpty
        ? 'routine'
        : _text(source['urgency']),
    preferredLanguage: _nonEmptyText(
      source['preferred_language'] ?? source['preferredLanguage'],
    ),
  );
}

Map<String, Object?> _map(Object? value) {
  return value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};
}

String _firstText(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _text(map[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _stableIbclcConsultId(String seed) {
  var hash = 0x811c9dc5;
  for (final codeUnit in seed.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 'ibclc_${hash.toRadixString(16).padLeft(8, '0')}';
}

String _text(Object? value) => value is String ? value.trim() : '';

String? _nonEmptyText(Object? value) => _nullIfEmpty(_text(value));

String? _nullIfEmpty(String value) => value.isEmpty ? null : value;
