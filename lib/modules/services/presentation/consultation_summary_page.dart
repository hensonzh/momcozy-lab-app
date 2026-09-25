import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_plan.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/summary_controller.dart';
import 'consultation_summary_content.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';

const careTaskStatusLabels = <CareTaskStatus, String>{
  CareTaskStatus.pending: 'To do',
  CareTaskStatus.inProgress: 'In progress',
  CareTaskStatus.completed: 'Completed',
  CareTaskStatus.skipped: 'Skip for now',
};

class ConsultationSummaryPage extends StatefulWidget {
  const ConsultationSummaryPage({
    super.key,
    required this.createController,
    required this.onBack,
    required this.onProgress,
    this.onPlan,
  });
  final CareSummaryController Function() createController;
  final VoidCallback onBack;
  final ValueChanged<CareEpisode> onProgress;
  final Future<void> Function()? onPlan;
  @override
  State<ConsultationSummaryPage> createState() =>
      _ConsultationSummaryPageState();
}

class _ConsultationSummaryPageState extends State<ConsultationSummaryPage>
    with WidgetsBindingObserver {
  late final controller = widget.createController();
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.load();
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (controller.data?.publication == null &&
          !controller.loading &&
          controller.failure == null) {
        controller.load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller.load();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: Scaffold(
      backgroundColor: MomHomeTokens.background,
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? 72
            : 64,
        centerTitle: false,
        title: Text(
          'Consultation summary',
          style: MomHomeTokens.text(20, weight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.chevron_left),
          color: MomHomeTokens.rose,
        ),
      ),
      body: MomCozyPageBody(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (controller.loading && controller.data == null)
                  const SummaryStateCard(
                    title: 'Loading consultation summary',
                    description:
                        'Please wait. You do not need to repeat this action.',
                    loading: true,
                  )
                else if (controller.loading || controller.busy)
                  const LinearProgressIndicator(),
                if (controller.failure case final failure?)
                  if (controller.data == null)
                    SummaryStateCard(
                      title: 'Could not load summary',
                      description:
                          'Reload to see the latest consultation summary.',
                      action: OutlinedButton(
                        onPressed: controller.busy ? null : controller.retry,
                        child: const Text('Reload'),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ProductErrorView(
                        useMomStyle: true,
                        failure: failure,
                        onRetry: controller.busy ? null : controller.retry,
                      ),
                    ),
                if (controller.failure?.code == 'plan_superseded')
                  Text(
                    'Your consultant published a new plan. Reload to continue.',
                    style: MomHomeTokens.text(13),
                  ),
                if (controller.uncertain)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Your feedback has not been confirmed. Try updating it again.',
                      style: MomHomeTokens.text(13),
                    ),
                  ),
                if (controller.data != null) ..._content(context),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _content(BuildContext context) => [
    ConsultationSummaryContent(
      data: controller.data!,
      onTask: _task,
      onProgress: () => widget.onProgress(controller.data!.episode),
      onPlan: widget.onPlan == null
          ? null
          : () async {
              await widget.onPlan!();
              if (mounted) await controller.load();
            },
    ),
  ];

  Future<void> _task(String sourceKey) => showDialog<void>(
    context: context,
    animationStyle: MomCozyMotion.animationStyle(context),
    barrierDismissible: false,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final task = controller.data?.publication?.tasks
            .where((value) => value.content.sourceKey == sourceKey)
            .firstOrNull;
        return PopScope(
          canPop: !controller.busy,
          child: Theme(
            data: momSettingsTheme(Theme.of(context)),
            child: MomSettingsFlowDialog(
              title: task?.content.title ?? 'Plan updated',
              closeLabel: 'Close action details',
              onClose: controller.busy ? null : () => Navigator.pop(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (task != null) ...[
                    Text(
                      task.content.description,
                      style: MomHomeTokens.text(14, height: 1.55),
                    ),
                    const SizedBox(height: 14),
                    MomSettingsCard(
                      color: MomHomeTokens.mint,
                      children: [
                        Text(
                          '${task.content.displayCategory} · ${task.content.displayDueLabel}',
                          style: MomHomeTokens.text(
                            12,
                            color: MomHomeTokens.secondary,
                          ),
                        ),
                        if (task.content.scheduledDate != null)
                          Text(
                            'Scheduled date: ${task.content.scheduledDate}',
                            style: MomHomeTokens.text(
                              12,
                              color: MomHomeTokens.secondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'My progress',
                      style: MomHomeTokens.text(14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            MediaQuery.textScalerOf(context).scale(1) > 1.4
                            ? 1
                            : 2;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final status in CareTaskStatus.values)
                              SizedBox(
                                width:
                                    (constraints.maxWidth - (columns - 1) * 8) /
                                    columns,
                                child: ChoiceChip(
                                  showCheckmark: false,
                                  labelPadding: EdgeInsets.zero,
                                  label: SizedBox(
                                    width:
                                        (constraints.maxWidth -
                                                (columns - 1) * 8) /
                                            columns -
                                        24,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (task.status == status) ...[
                                          const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: MomHomeTokens.rose,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Flexible(
                                          child: Text(
                                            careTaskStatusLabels[status]!,
                                            textAlign: TextAlign.center,
                                            style: MomHomeTokens.text(
                                              13,
                                              weight: FontWeight.w700,
                                              color: task.status == status
                                                  ? MomHomeTokens.rose
                                                  : MomHomeTokens.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  selected: task.status == status,
                                  selectedColor: MomCozyColors.roseSoft,
                                  backgroundColor: MomHomeTokens.surface,
                                  disabledColor: task.status == status
                                      ? MomCozyColors.roseSoft
                                      : MomHomeTokens.surface,
                                  checkmarkColor: MomHomeTokens.rose,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: const BorderSide(
                                    color: MomHomeTokens.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  onSelected: controller.canUpdate
                                      ? (_) => controller.update(task, status)
                                      : null,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ] else
                    Text(
                      'This action may have changed. Close it to review the latest summary.',
                      style: MomHomeTokens.text(13, height: 1.55),
                    ),
                  if (controller.busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (controller.uncertain && !controller.busy)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        'Your feedback has not been confirmed. Try updating it again.',
                        style: MomHomeTokens.text(13, height: 1.55),
                      ),
                    ),
                  if (controller.failure case final failure?)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: ProductErrorView(
                        useMomStyle: true,
                        failure: failure,
                        onRetry: controller.busy ? null : controller.retry,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
