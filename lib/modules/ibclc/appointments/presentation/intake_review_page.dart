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
            label: const Text('返回预约'),
          ),
        ),
        const SizedBox(height: 16),
        WorkbenchHeading(
          title: '咨询前资料',
          subtitle: intake == null ? null : '用户提交 · 第 ${intake.version} 版',
          actions: [
            OutlinedButton.icon(
              onPressed: widget.onRoom,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('进入咨询室'),
            ),
            IconButton(
              tooltip: '刷新咨询资料',
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (loading) const LinearProgressIndicator(semanticsLabel: '正在读取咨询资料'),
        if (failure?.code == 'not_found')
          const Card(
            child: ProductEmptyView(
              title: '用户尚未提交咨询资料',
              description: '用户完成咨询准备后，可在这里查看。',
            ),
          )
        else if (failure?.code == 'consent_required')
          const Card(
            child: ProductEmptyView(
              title: '病例授权已撤回',
              description: '客户重新授权后才能查看本次咨询资料。',
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
                    '当前困扰',
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
                  _Field('希望改善', content.feedingGoal),
                  _Field('需要的支持', content.supportNeeded),
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
                    '妈妈与宝宝',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  _Field('妈妈分娩日期', content.profile.deliveryDate.toString()),
                  _Field('所在地', content.profile.region),
                  _Field('宝宝', content.profile.baby.name),
                  _Field(
                    '出生日期',
                    content.profile.baby.birthDate?.toString() ?? '未填写',
                  ),
                  _Field('宝宝性别', switch (content.profile.baby.sex) {
                    BabySex.female => '女',
                    BabySex.male => '男',
                    BabySex.unspecified => '未填写',
                  }),
                  _Field(
                    '喂养方式',
                    content.profile.baby.feedingMode == FeedingMode.unknown
                        ? '未填写'
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
            value.isEmpty ? '未填写' : value,
            style: const TextStyle(height: 1.6),
          ),
        ),
      ],
    ),
  );
}
