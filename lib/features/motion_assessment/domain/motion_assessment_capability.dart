enum MotionAssessmentTarget {
  forwardHead,
  shoulderHeightAsymmetry,
  trunkLateralLean,
  roundedShoulders,
  pelvicTilt,
  kneeAlignment,
  gait,
}

extension MotionAssessmentTargetValue on MotionAssessmentTarget {
  String get wireValue => switch (this) {
    MotionAssessmentTarget.forwardHead => 'forward_head',
    MotionAssessmentTarget.shoulderHeightAsymmetry =>
      'shoulder_height_asymmetry',
    MotionAssessmentTarget.trunkLateralLean => 'trunk_lateral_lean',
    MotionAssessmentTarget.roundedShoulders => 'rounded_shoulders',
    MotionAssessmentTarget.pelvicTilt => 'pelvic_tilt',
    MotionAssessmentTarget.kneeAlignment => 'knee_alignment',
    MotionAssessmentTarget.gait => 'gait',
  };

  static MotionAssessmentTarget? fromWireValue(String value) {
    final normalized = value.trim().toLowerCase();
    for (final target in MotionAssessmentTarget.values) {
      if (target.wireValue == normalized) return target;
    }
    return null;
  }
}

class MotionAssessmentCapability {
  const MotionAssessmentCapability({
    required this.target,
    required this.label,
    required this.available,
    required this.requiredView,
    this.unavailableReason = '',
  });

  final MotionAssessmentTarget target;
  final String label;
  final bool available;
  final String requiredView;
  final String unavailableReason;

  Map<String, Object?> toRealtimeJson() => {
    'target': target.wireValue,
    'label': label,
    'available': available,
    'required_view': requiredView,
    if (unavailableReason.isNotEmpty) 'unavailable_reason': unavailableReason,
  };
}

class MotionAssessmentCapabilityRegistry {
  const MotionAssessmentCapabilityRegistry(this.all);

  final List<MotionAssessmentCapability> all;

  List<MotionAssessmentCapability> get available =>
      all.where((item) => item.available).toList(growable: false);

  MotionAssessmentCapability byTarget(MotionAssessmentTarget target) =>
      all.firstWhere((item) => item.target == target);
}

const motionAssessmentCapabilities = MotionAssessmentCapabilityRegistry([
  MotionAssessmentCapability(
    target: MotionAssessmentTarget.forwardHead,
    label: 'Forward head posture',
    available: true,
    requiredView: 'side',
  ),
  MotionAssessmentCapability(
    target: MotionAssessmentTarget.shoulderHeightAsymmetry,
    label: 'Uneven shoulders',
    available: true,
    requiredView: 'front',
  ),
  MotionAssessmentCapability(
    target: MotionAssessmentTarget.trunkLateralLean,
    label: 'Sideways trunk lean',
    available: true,
    requiredView: 'front',
  ),
  MotionAssessmentCapability(
    target: MotionAssessmentTarget.roundedShoulders,
    label: 'Rounded shoulders',
    available: false,
    requiredView: 'side',
    unavailableReason: 'validated_lateral_depth_protocol_required',
  ),
  MotionAssessmentCapability(
    target: MotionAssessmentTarget.pelvicTilt,
    label: 'Pelvic tilt',
    available: false,
    requiredView: 'front',
    unavailableReason: 'validated_pelvic_landmarks_required',
  ),
  MotionAssessmentCapability(
    target: MotionAssessmentTarget.kneeAlignment,
    label: 'Knee alignment',
    available: false,
    requiredView: 'front',
    unavailableReason: 'lower_body_protocol_validation_required',
  ),
  MotionAssessmentCapability(
    target: MotionAssessmentTarget.gait,
    label: 'Gait',
    available: false,
    requiredView: 'dynamic',
    unavailableReason: 'platform_parity_and_protocol_validation_required',
  ),
]);
