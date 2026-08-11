import 'dart:convert';

/// Bounded semantic state shared with the dedicated Realtime voice session.
///
/// Raw camera frames and pose landmarks are intentionally not represented in
/// this contract. The on-device quality gate remains authoritative for frame
/// acceptance and final measurement classification.
class MotionAssessmentContextSnapshot {
  const MotionAssessmentContextSnapshot({
    required this.assessmentId,
    required this.sequence,
    required this.observedAtMs,
    required this.target,
    required this.phase,
    required this.elapsedMs,
    required this.personCount,
    required this.targetLocked,
    required this.continuity,
    required this.assessmentRegionVisible,
    required this.missingRegions,
    this.requiredRegions = const ['head', 'shoulders'],
    required this.distance,
    required this.requiredView,
    required this.detectedView,
    required this.detectedSide,
    required this.alignmentQuality,
    required this.samplingState,
    required this.validSamples,
    required this.requiredSamples,
    required this.stableDurationMs,
    required this.requiredDurationMs,
    required this.samplingProgress,
    required this.rejectionReasons,
    required this.measurementStatus,
    required this.metric,
    required this.rollingMedian,
    required this.dispersion,
    required this.unit,
    required this.multiplePeople,
    required this.targetChanged,
    required this.discomfortReported,
    required this.recommendedAction,
    required this.guidanceReason,
    this.freshForMs = 1500,
    this.measurementQualityScore,
    this.selectedTargets = const [],
    this.planRevision = 0,
    this.planConfirmed = false,
  });

  factory MotionAssessmentContextSnapshot.selection({
    required String assessmentId,
    required int sequence,
    required List<String> selectedTargets,
    required int planRevision,
    required bool planConfirmed,
  }) {
    return MotionAssessmentContextSnapshot(
      assessmentId: assessmentId,
      sequence: sequence,
      observedAtMs: 0,
      target: 'posture_screen',
      phase: planConfirmed ? 'plan_confirmed' : 'selecting_assessments',
      elapsedMs: 0,
      personCount: 0,
      targetLocked: false,
      continuity: 'not_started',
      assessmentRegionVisible: false,
      missingRegions: const [],
      distance: 'not_started',
      requiredView: 'not_selected',
      detectedView: 'not_started',
      detectedSide: 'unknown',
      alignmentQuality: 'not_started',
      samplingState: 'not_started',
      validSamples: 0,
      requiredSamples: 0,
      stableDurationMs: 0,
      requiredDurationMs: 0,
      samplingProgress: 0,
      rejectionReasons: const [],
      measurementStatus: 'unavailable',
      metric: 'not_started',
      rollingMedian: null,
      dispersion: null,
      unit: 'degrees',
      multiplePeople: false,
      targetChanged: false,
      discomfortReported: false,
      recommendedAction: planConfirmed
          ? 'prepare_first_capture_step'
          : 'select_assessment_targets',
      guidanceReason: planConfirmed
          ? 'plan_confirmed'
          : 'assessment_selection_required',
      selectedTargets: selectedTargets,
      planRevision: planRevision,
      planConfirmed: planConfirmed,
    );
  }

  final String assessmentId;
  final int sequence;
  final int observedAtMs;
  final int freshForMs;
  final String target;
  final String phase;
  final int elapsedMs;
  final int personCount;
  final bool targetLocked;
  final String continuity;
  final bool assessmentRegionVisible;
  final List<String> missingRegions;
  final List<String> requiredRegions;
  final String distance;
  final String requiredView;
  final String detectedView;
  final String detectedSide;
  final String alignmentQuality;
  final String samplingState;
  final int validSamples;
  final int requiredSamples;
  final int stableDurationMs;
  final int requiredDurationMs;
  final double samplingProgress;
  final List<String> rejectionReasons;
  final String measurementStatus;
  final String metric;
  final double? rollingMedian;
  final double? dispersion;
  final String unit;
  final double? measurementQualityScore;
  final bool multiplePeople;
  final bool targetChanged;
  final bool discomfortReported;
  final String recommendedAction;
  final String guidanceReason;
  final List<String> selectedTargets;
  final int planRevision;
  final bool planConfirmed;

  Map<String, Object?> toJson() {
    return {
      'schema_version': 'motion_assessment.context.v4',
      'assessment_id': assessmentId,
      'sequence': sequence,
      'observed_at_ms': observedAtMs,
      'fresh_for_ms': freshForMs,
      'assessment': {'target': target, 'phase': phase, 'elapsed_ms': elapsedMs},
      if (target == 'posture_screen')
        'plan': {
          'selected_targets': selectedTargets,
          'revision': planRevision,
          'confirmed': planConfirmed,
        },
      'subject': {
        'person_count': personCount,
        'target_locked': targetLocked,
        'continuity': continuity,
      },
      'framing': {
        'assessment_region_visible': assessmentRegionVisible,
        'required_regions': requiredRegions,
        'missing_regions': missingRegions,
        'distance': distance,
      },
      'orientation': {
        'required_view': requiredView,
        'detected_view': detectedView,
        'detected_side': detectedSide,
        'alignment_quality': alignmentQuality,
      },
      'sampling': {
        'state': samplingState,
        'valid_samples': validSamples,
        'required_samples': requiredSamples,
        'stable_duration_ms': stableDurationMs,
        'required_duration_ms': requiredDurationMs,
        'progress': double.parse(
          samplingProgress.clamp(0, 1).toStringAsFixed(3),
        ),
        'rejection_reasons': rejectionReasons,
      },
      'measurement': {
        'status': measurementStatus,
        'metric': metric,
        if (rollingMedian != null)
          'rolling_median': double.parse(rollingMedian!.toStringAsFixed(2)),
        if (dispersion != null)
          'dispersion': double.parse(dispersion!.toStringAsFixed(2)),
        'unit': unit,
        if (measurementQualityScore != null)
          'measurement_quality_score': double.parse(
            measurementQualityScore!.clamp(0, 1).toStringAsFixed(3),
          ),
      },
      'safety': {
        'multiple_people': multiplePeople,
        'target_changed': targetChanged,
        'discomfort_reported': discomfortReported,
      },
      'guidance': {
        'recommended_action': recommendedAction,
        'reason': guidanceReason,
      },
    };
  }

  String toRealtimeInstructions({int contextAgeMs = 0}) {
    if (phase == 'selecting_assessments' || phase == 'plan_confirmed') {
      return '''
请基于下面“最新评估项目计划”回应用户刚才的语音：
${jsonEncode(toJson())}

当前仍在项目选择阶段，没有姿态画面结论。可以根据用户刚才的明确语音调用 motion_assessment_plan；更新、增加或移除项目必须使用这里的 revision，用户明确确认当前选择时才调用 confirm。最多说两句：简短复述选择，再说清唯一的下一步。不要寒暄、要求用户站位或虚构姿态结果。
'''
          .trim();
    }
    return '''
请基于下面“最新端侧姿态语义快照”回答用户刚才的语音问题。快照可能比对话历史更新：
${jsonEncode(toJson())}
快照当前年龄：${contextAgeMs.clamp(0, 1 << 31)} ms。

约束：本地质量门是权威来源；不得推翻 accept/reject、多人暂停或最终 classification。普通回答最多两句；动作指导只说一句，尽量不超过 18 个汉字。不要寒暄、解释检测过程、重复鼓励或预告后续。若快照已过 fresh_for_ms，只说明正在重新确认画面，不猜测当前姿态。不要声称持续观看视频或看到原始关键点，不作医疗诊断。
'''
        .trim();
  }
}
