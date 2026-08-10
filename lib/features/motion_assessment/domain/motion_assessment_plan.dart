import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_capability.dart';

enum MotionAssessmentPlanAction { replace, add, remove, confirm }

enum MotionAssessmentCaptureView { side, front }

class MotionAssessmentPlanMutation {
  const MotionAssessmentPlanMutation({
    required this.action,
    required this.targets,
    required this.expectedRevision,
  });

  final MotionAssessmentPlanAction action;
  final List<MotionAssessmentTarget> targets;
  final int expectedRevision;
}

class MotionAssessmentCaptureStep {
  const MotionAssessmentCaptureStep({
    required this.id,
    required this.view,
    required this.targets,
    this.requiredSide,
  });

  final String id;
  final MotionAssessmentCaptureView view;
  final Set<MotionAssessmentTarget> targets;
  final String? requiredSide;
}

class MotionAssessmentPlanException implements Exception {
  const MotionAssessmentPlanException(this.code, {this.details = const {}});

  final String code;
  final Map<String, Object?> details;
}

class MotionAssessmentPlan {
  const MotionAssessmentPlan({
    required this.selectedTargets,
    required this.revision,
    required this.confirmed,
  });

  factory MotionAssessmentPlan.initial() => const MotionAssessmentPlan(
    selectedTargets: [],
    revision: 0,
    confirmed: false,
  );

  factory MotionAssessmentPlan.fromSession({
    required Iterable<String> targets,
    required int revision,
    required bool confirmed,
  }) {
    final parsed = targets
        .map(MotionAssessmentTargetValue.fromWireValue)
        .whereType<MotionAssessmentTarget>();
    return MotionAssessmentPlan(
      selectedTargets: _ordered(parsed),
      revision: revision,
      confirmed: confirmed,
    );
  }

  final List<MotionAssessmentTarget> selectedTargets;
  final int revision;
  final bool confirmed;

  MotionAssessmentPlan apply({
    required MotionAssessmentPlanAction action,
    required Iterable<MotionAssessmentTarget> targets,
    required int expectedRevision,
  }) {
    if (expectedRevision != revision) {
      throw MotionAssessmentPlanException(
        'plan_revision_conflict',
        details: {'current_revision': revision},
      );
    }
    final requested = _ordered(targets);
    final unavailable = requested
        .where(
          (target) => !motionAssessmentCapabilities.byTarget(target).available,
        )
        .toList(growable: false);
    if (unavailable.isNotEmpty) {
      throw MotionAssessmentPlanException(
        'assessment_target_unavailable',
        details: {
          'unavailable_targets': [
            for (final target in unavailable)
              {
                'target': target.wireValue,
                'reason': motionAssessmentCapabilities
                    .byTarget(target)
                    .unavailableReason,
              },
          ],
        },
      );
    }

    if (action == MotionAssessmentPlanAction.confirm) {
      if (selectedTargets.isEmpty) {
        throw const MotionAssessmentPlanException('assessment_plan_empty');
      }
      return MotionAssessmentPlan(
        selectedTargets: selectedTargets,
        revision: revision + 1,
        confirmed: true,
      );
    }

    final next = switch (action) {
      MotionAssessmentPlanAction.replace => requested,
      MotionAssessmentPlanAction.add => _ordered([
        ...selectedTargets,
        ...requested,
      ]),
      MotionAssessmentPlanAction.remove =>
        selectedTargets
            .where((target) => !requested.contains(target))
            .toList(growable: false),
      MotionAssessmentPlanAction.confirm => selectedTargets,
    };
    return MotionAssessmentPlan(
      selectedTargets: next,
      revision: revision + 1,
      confirmed: false,
    );
  }

  List<MotionAssessmentCaptureStep> get captureSteps {
    final steps = <MotionAssessmentCaptureStep>[];
    if (selectedTargets.contains(MotionAssessmentTarget.forwardHead)) {
      steps.addAll(const [
        MotionAssessmentCaptureStep(
          id: 'forward_head_side_1',
          view: MotionAssessmentCaptureView.side,
          targets: {MotionAssessmentTarget.forwardHead},
        ),
        MotionAssessmentCaptureStep(
          id: 'forward_head_side_2',
          view: MotionAssessmentCaptureView.side,
          targets: {MotionAssessmentTarget.forwardHead},
          requiredSide: 'opposite',
        ),
      ]);
    }
    final frontal = selectedTargets
        .where(
          (target) =>
              target == MotionAssessmentTarget.shoulderHeightAsymmetry ||
              target == MotionAssessmentTarget.trunkLateralLean,
        )
        .toSet();
    if (frontal.isNotEmpty) {
      steps.add(
        MotionAssessmentCaptureStep(
          id: 'frontal_posture',
          view: MotionAssessmentCaptureView.front,
          targets: Set.unmodifiable(frontal),
        ),
      );
    }
    return List.unmodifiable(steps);
  }

  List<String> get wireTargets =>
      selectedTargets.map((target) => target.wireValue).toList(growable: false);

  static List<MotionAssessmentTarget> _ordered(
    Iterable<MotionAssessmentTarget> targets,
  ) {
    final values = targets.toSet();
    return MotionAssessmentTarget.values
        .where(values.contains)
        .toList(growable: false);
  }
}
