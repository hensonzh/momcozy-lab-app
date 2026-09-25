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
Respond to the user's latest speech using the current assessment plan below:
${jsonEncode(toJson())}

The user is still choosing assessment areas; there are no posture conclusions yet. You may call motion_assessment_plan based on their explicit speech. Use the revision shown here when updating, adding, or removing areas. Call confirm only when the user clearly confirms the current selection. Speak at most two sentences: briefly repeat the choice and give one next step. Do not add greetings, positioning instructions, or invented results. Respond in English.
'''
          .trim();
    }
    return '''
Answer the user's latest spoken question using this on-device semantic posture snapshot, which may be newer than the conversation history:
${jsonEncode(toJson())}
Snapshot age: ${contextAgeMs.clamp(0, 1 << 31)} ms.

Constraints: the on-device quality gate is authoritative. Do not override accept/reject, multi-person pause, or final classification. Ordinary answers use at most two sentences; movement guidance uses one sentence, ideally under 12 words. Do not add greetings, explain detection, repeatedly encourage, or preview later steps. If the snapshot is older than fresh_for_ms, say only that the view is being checked again; do not guess the current posture. Do not claim to watch continuous video or see raw keypoints, and do not make a medical diagnosis. Respond in English.
'''
        .trim();
  }
}
