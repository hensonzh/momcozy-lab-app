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
    required this.fullBodyVisible,
    required this.missingRegions,
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
  });

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
  final bool fullBodyVisible;
  final List<String> missingRegions;
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

  Map<String, Object?> toJson() {
    return {
      'schema_version': 'motion_assessment.context.v2',
      'assessment_id': assessmentId,
      'sequence': sequence,
      'observed_at_ms': observedAtMs,
      'fresh_for_ms': freshForMs,
      'assessment': {'target': target, 'phase': phase, 'elapsed_ms': elapsedMs},
      'subject': {
        'person_count': personCount,
        'target_locked': targetLocked,
        'continuity': continuity,
      },
      'framing': {
        'full_body_visible': fullBodyVisible,
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
    return '''
请基于下面“最新端侧姿态语义快照”回答用户刚才的语音问题。快照可能比对话历史更新：
${jsonEncode(toJson())}
快照当前年龄：${contextAgeMs.clamp(0, 1 << 31)} ms。

约束：本地质量门是权威来源；不得推翻 accept/reject、多人暂停或最终 classification。只解释当前画面趋势和下一步动作，一次只给一个简短动作。若快照已过 fresh_for_ms，只说明正在重新确认画面，不猜测当前姿态。不要声称看到原始视频或关键点，不作医疗诊断。
'''
        .trim();
  }
}
