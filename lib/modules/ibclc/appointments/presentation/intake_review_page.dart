import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/baby/baby_profile.dart';
import '../../../../domain/care/intake.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/product_failure.dart';
import '../../../../shared/care/care_labels.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/widgets/product_feedback.dart';
import '../../shared/workbench_widgets.dart';

class IntakeReviewPage extends StatefulWidget {
  const IntakeReviewPage({
    super.key,
    required this.repository,
    required this.appointmentId,
    required this.onBack,
    required this.onRoom,
  });
  final WorkbenchRepository repository;
  final String appointmentId;
  final VoidCallback onBack, onRoom;
  @override
  State<IntakeReviewPage> createState() => _IntakeReviewPageState();
}

class _IntakeReviewPageState extends State<IntakeReviewPage>
    with WidgetsBindingObserver {
  CareIntake? data;
  ProductFailure? failure;
  bool loading = true;
  int generation = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!loading) unawaited(_load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final current = ++generation;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final result = await widget.repository.intake(widget.appointmentId);
      if (!mounted || generation != current) return;
      setState(() => data = result);
    } catch (error) {
      if (!mounted || generation != current) return;
      setState(() {
        data = null;
        failure = error is ProductFailure
            ? error
            : const ProductFailure(ProductFailureKind.unavailable);
      });
    }
    if (mounted && generation == current) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final intake = data;
    final content = intake?.content;
    return WorkbenchPageBody(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to appointments'),
          ),
        ),
        const SizedBox(height: 16),
        WorkbenchHeading(
          title: 'Consultation intake',
          subtitle: intake == null ? null : 'Client submission · Version ${intake.version}',
          actions: [
            OutlinedButton.icon(
              onPressed: widget.onRoom,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Join consultation'),
            ),
            IconButton(
              tooltip: 'Refresh intake',
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (loading) const LinearProgressIndicator(semanticsLabel: 'Loading intake'),
        if (failure?.code == 'not_found')
          const Card(
            child: ProductEmptyView(
              title: 'Client has not submitted intake yet',
              description: 'You can view it here once the client completes their consultation preparation.',
            ),
          )
        else if (failure?.code == 'consent_required')
          const Card(
            child: ProductEmptyView(
              title: 'Case access consent withdrawn',
              description: 'The client must give consent again before you can view this intake.',
            ),
          )
        else if (failure != null)
          ProductErrorView(failure: failure!, onRetry: _load),
        if (content != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Current concerns',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final symptom in content.symptoms)
                        WorkbenchBadge(
                          intakeSymptomLabels[symptom]!,
                          color: MomCozyColors.primary,
                          background: MomCozyColors.roseSoft,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Field('Desired outcome', content.feedingGoal),
                  _Field('Support needed', content.supportNeeded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mom & baby',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  _Field('Delivery date', content.profile.deliveryDate.toString()),
                  _Field('State', content.profile.region),
                  _Field('Baby', content.profile.baby.name),
                  _Field(
                    'Date of birth',
                    content.profile.baby.birthDate?.toString() ?? 'Not provided',
                  ),
                  _Field('Baby\'s sex', switch (content.profile.baby.sex) {
                    BabySex.female => 'Female',
                    BabySex.male => 'Male',
                    BabySex.unspecified => 'Not provided',
                  }),
                  _Field(
                    'Feeding method',
                    content.profile.baby.feedingMode == FeedingMode.unknown
                        ? 'Not provided'
                        : feedingModeLabels[content.profile.baby.feedingMode]!,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: MomCozyColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        SelectionArea(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(height: 1.6),
          ),
        ),
      ],
    ),
  );
}
