import '../../../shared/care/care_labels.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/intake.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/intake_controller.dart';
import 'appointment_summary.dart';

class IntakePage extends StatefulWidget {
  const IntakePage({
    super.key,
    required this.repository,
    required this.appointmentId,
    required this.onBack,
    required this.onManageBabies,
    required this.onPreconsult,
    this.now,
  });
  final IntakeRepository repository;
  final String appointmentId;
  final VoidCallback onBack;
  final Future<void> Function() onManageBabies;
  final ValueChanged<CareIntake> onPreconsult;
  final DateTime Function()? now;
  @override
  State<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends State<IntakePage> {
  bool _allowPop = false;
  late final controller = IntakeController(
    repository: widget.repository,
    appointmentId: widget.appointmentId,
    now: widget.now,
  );
  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (controller.busy) return;
    if (controller.dirty &&
        !await confirmDiscard(
          context,
          uncertainSave: controller.uncertainSave,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) widget.onBack();
  }

  Future<void> _reload() async {
    if (controller.dirty &&
        !await confirmDiscard(
          context,
          uncertainSave: controller.uncertainSave,
        )) {
      return;
    }
    if (mounted) await controller.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope(
      canPop: _allowPop || (!controller.dirty && !controller.busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: controller.busy ? null : _close),
          title: const Text('信息采集表'),
        ),
        body: MomCozyPageBody(child: _body()),
      ),
    ),
  );

  Widget _body() {
    if (controller.loading) {
      return const ProductLoadingView();
    }
    final data = controller.data;
    if (data == null) {
      return ProductErrorView(
        failure:
            controller.failure ??
            const ProductFailure(ProductFailureKind.unavailable),
        onRetry: _reload,
      );
    }
    if (![
      AppointmentStatus.confirmed,
      AppointmentStatus.inProgress,
    ].contains(data.appointment.status)) {
      return const ProductEmptyView(
        title: '请先确认预约时间',
        description: '信息采集表会与已确认的咨询关联。',
      );
    }
    if (data.babies.isEmpty) {
      return ProductEmptyView(
        title: '请先添加宝宝档案',
        description: '将本次咨询与宝宝关联，方便你和专家查看同一份记录。',
        action: FilledButton(
          onPressed: () async {
            await widget.onManageBabies();
            if (mounted) await controller.load();
          },
          child: const Text('添加宝宝档案'),
        ),
      );
    }
    return ListView(
      padding: MomCozyInsets.page,
      children: [
        if (data.previousIntake != null && data.intake == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              '已带入上次填写的内容，请核对本次情况并重新确认授权。',
              style: TextStyle(
                color: MomCozyColors.mutedForeground,
                fontSize: MomCozyTypography.captionSize,
                height: 1.6,
              ),
            ),
          ),
        MomCozySurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '这次最想解决什么？',
                style: TextStyle(
                  fontSize: MomCozyTypography.bodyLargeSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: MomCozySpacing.xs),
              const Text(
                '可多选',
                style: TextStyle(
                  color: MomCozyColors.mutedForeground,
                  fontSize: MomCozyTypography.captionSize,
                ),
              ),
              const SizedBox(height: MomCozySpacing.content),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in intakeSymptomLabels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: controller.symptoms.contains(entry.key),
                      onSelected: controller.canEdit
                          ? (_) => controller.toggleSymptom(entry.key)
                          : null,
                      selectedColor: MomCozyColors.careSoft,
                      labelStyle: TextStyle(
                        fontSize: MomCozyTypography.secondarySize,
                        color: controller.symptoms.contains(entry.key)
                            ? MomCozyColors.care
                            : MomCozyColors.foreground,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: MomCozySpacing.card),
              _text(
                'goal',
                '希望咨询后有什么变化？',
                controller.goal,
                (value) => controller.goal = value,
                hint: '例如：减少含乳疼痛，找到合适的喂养节奏',
                lines: 3,
                max: 1000,
              ),
              const SizedBox(height: MomCozySpacing.content),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: const Text(
                  '补充情况',
                  style: TextStyle(fontSize: MomCozyTypography.bodySize),
                ),
                subtitle: Text(controller.support.isEmpty ? '可选' : '已填写'),
                children: [
                  const Text(
                    '可以补充近期体重、黄疸、用药，或近 24 小时喂养与泵奶情况。',
                    style: TextStyle(
                      fontSize: MomCozyTypography.captionSize,
                      color: MomCozyColors.mutedForeground,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: MomCozySpacing.content),
                  _text(
                    'support',
                    '还想让 IBCLC 知道什么？',
                    controller.support,
                    (value) => controller.support = value,
                    lines: 3,
                    max: 3000,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MomCozySpacing.page),
        MomCozySurface(
          child: ExpansionTile(
            key: ValueKey('profile-${controller.draftRevision}'),
            initiallyExpanded: !controller.profileReady,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 12, bottom: 8),
            title: const Text(
              '基础信息',
              style: TextStyle(
                fontSize: MomCozyTypography.bodyLargeSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(controller.profileReady ? '已预填，可修改' : '需完善'),
            children: [_profile()],
          ),
        ),
        const SizedBox(height: MomCozySpacing.page),
        MomCozySurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: MomCozySpacing.compact),
                  const Expanded(
                    child: Text(
                      '信息使用',
                      style: TextStyle(
                        fontSize: MomCozyTypography.bodyLargeSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _consentInfo,
                    child: const Text('查看说明'),
                  ),
                ],
              ),
              CheckboxListTile(
                key: const ValueKey('intake-consent'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: controller.consent,
                onChanged: controller.canEdit
                    ? (value) => controller.change(
                        () => controller.consent = value ?? false,
                      )
                    : null,
                title: const Text(
                  '允许本次服务的 IBCLC 查看此表',
                  style: TextStyle(fontSize: MomCozyTypography.bodySize),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MomCozySpacing.page),
        if (controller.validation != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                controller.validation!,
                style: const TextStyle(color: MomCozyColors.danger),
              ),
            ),
          ),
        if (controller.failure case final failure?)
          ProductErrorView(
            failure: failure,
            preserveDraft: true,
            onRetry: controller.uncertainSave ? null : _reload,
          ),
        FilledButton(
          onPressed: controller.busy ? null : _save,
          child: Text(
            controller.busy
                ? '正在保存…'
                : controller.uncertainSave
                ? '重试保存'
                : controller.saved == null
                ? '保存信息'
                : '保存修改',
          ),
        ),
      ],
    );
  }

  Widget _profile() => Column(
    children: [
      if (controller.data!.babies.length > 1) ...[
        DropdownButtonFormField<String>(
          initialValue: controller.babyId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '本次咨询的宝宝'),
          items: controller.data!.babies
              .map(
                (baby) =>
                    DropdownMenuItem(value: baby.id, child: Text(baby.name)),
              )
              .toList(),
          onChanged: controller.canEdit ? controller.selectBaby : null,
        ),
        const SizedBox(height: MomCozySpacing.page),
      ],
      DropdownButtonFormField<String>(
        initialValue: controller.region,
        decoration: const InputDecoration(labelText: '当前所在州'),
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: 'CA', child: Text('California (CA)')),
          DropdownMenuItem(value: 'NY', child: Text('New York (NY)')),
          DropdownMenuItem(value: 'TX', child: Text('Texas (TX)')),
        ],
        onChanged: controller.canEdit
            ? (value) => controller.change(() => controller.region = value)
            : null,
      ),
      const SizedBox(height: MomCozySpacing.page),
      _text(
        'postpartum',
        '产后天数',
        controller.postpartumDays,
        (value) => controller.postpartumDays = value,
        numeric: true,
      ),
      const SizedBox(height: MomCozySpacing.page),
      _text(
        'baby-name',
        '宝宝称呼',
        controller.babyName,
        (value) => controller.babyName = value,
        max: 120,
      ),
      const SizedBox(height: MomCozySpacing.page),
      TextFormField(
        key: ValueKey('birth-${controller.babyBirthDate}'),
        initialValue: controller.babyBirthDate?.toString() ?? '',
        readOnly: true,
        enabled: controller.canEdit,
        decoration: const InputDecoration(
          labelText: '宝宝出生日期',
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        onTap: _birthDate,
      ),
      const SizedBox(height: MomCozySpacing.page),
      DropdownButtonFormField<BabySex>(
        initialValue: controller.babySex,
        decoration: const InputDecoration(labelText: '出生记录性别'),
        items: const [
          DropdownMenuItem(
            value: BabySex.unspecified,
            enabled: false,
            child: Text('请选择'),
          ),
          DropdownMenuItem(value: BabySex.female, child: Text('女宝宝')),
          DropdownMenuItem(value: BabySex.male, child: Text('男宝宝')),
        ],
        onChanged: controller.canEdit
            ? (value) => controller.change(
                () => controller.babySex = value ?? BabySex.unspecified,
              )
            : null,
      ),
      const SizedBox(height: MomCozySpacing.page),
      DropdownButtonFormField<FeedingMode>(
        initialValue: controller.feedingMode,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '当前喂养方式'),
        items: feedingModeLabels.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                enabled: entry.key != FeedingMode.unknown,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: controller.canEdit
            ? (value) => controller.change(
                () => controller.feedingMode = value ?? FeedingMode.unknown,
              )
            : null,
      ),
    ],
  );

  Widget _text(
    String key,
    String label,
    String value,
    ValueChanged<String> changed, {
    int lines = 1,
    int? max,
    String? hint,
    bool numeric = false,
  }) => TextFormField(
    key: ValueKey('$key-${controller.draftRevision}'),
    initialValue: value,
    enabled: controller.canEdit,
    maxLines: lines,
    maxLength: max,
    keyboardType: numeric
        ? TextInputType.number
        : lines > 1
        ? TextInputType.multiline
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      counterText: '',
    ),
    onChanged: (value) => controller.change(() => changed(value)),
  );
  Future<void> _birthDate() async {
    final today = controller.today, current = controller.babyBirthDate ?? today;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (date != null && mounted) {
      controller.change(
        () => controller.babyBirthDate = LocalDate.fromDateTime(date),
      );
    }
  }

  Future<void> _consentInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('信息使用说明'),
      content: const Text(
        '提供给谁\n本次服务中被分配的 IBCLC。\n\n包含什么\n本页填写内容与确认后的基础信息。\n\n用于什么\n咨询前了解情况与准备咨询。\n\n你可以在隐私与授权中撤回，撤回后专家不能再次打开本表。',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
  Future<void> _save() async {
    final result = await controller.save();
    if (result == null || !mounted) return;
    final preconsult = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('信息采集已完成'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppointmentSummary(appointment: controller.data!.appointment),
              const SizedBox(height: MomCozySpacing.page),
              const Text('你可以继续与 Cozymate 聊一聊，梳理这次咨询重点。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后再说，查看预约'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始预问诊'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (preconsult == true) {
      widget.onPreconsult(result);
    } else {
      widget.onBack();
    }
  }
}
