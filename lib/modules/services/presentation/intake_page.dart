import '../../../shared/care/care_labels.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_age_label.dart';
import '../../../domain/mother/postpartum_stage.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/intake.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/confirm_discard.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/intake_controller.dart';
import 'mom_appointment_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';

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
          theme: momSettingsTheme(Theme.of(context)),
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
          theme: momSettingsTheme(Theme.of(context)),
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
      child: Theme(
        data: momSettingsTheme(Theme.of(context)),
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? 96
                : 56,
            leadingWidth: MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? 88
                : 64,
            leading: TextButton(
              onPressed: controller.busy ? null : _close,
              child: const Text('返回'),
            ),
            centerTitle: false,
            title: Text(
              '信息采集表',
              style: MomHomeTokens.text(22, weight: FontWeight.w700),
            ),
          ),
          body: ClipRect(child: MomCozyPageBody(child: _body())),
        ),
      ),
    ),
  );

  Widget _body() {
    if (controller.loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MomSettingsCard(
            children: [
              Text(
                '正在载入',
                style: MomHomeTokens.text(16, weight: FontWeight.w700),
              ),
              const LinearProgressIndicator(),
            ],
          ),
        ],
      );
    }
    final data = controller.data;
    if (data == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MomSettingsCard(
            children: [
              ProductErrorView(
                failure:
                    controller.failure ??
                    const ProductFailure(ProductFailureKind.unavailable),
                onRetry: _reload,
              ),
            ],
          ),
        ],
      );
    }
    if (![
      AppointmentStatus.confirmed,
      AppointmentStatus.inProgress,
    ].contains(data.appointment.status)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MomSettingsCard(
            children: [
              Text(
                '请先确认预约时间',
                style: MomHomeTokens.text(18, weight: FontWeight.w700),
              ),
              Text(
                '信息采集表会与已确认的咨询关联。',
                style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
              ),
            ],
          ),
        ],
      );
    }
    if (data.babies.isEmpty) {
      return ProductEmptyView(
        textAlign: TextAlign.start,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (data.previousIntake != null && data.intake == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              '已带入上次填写的内容，请核对本次情况并重新确认授权。',
              style: TextStyle(
                color: MomHomeTokens.secondary,
                fontSize: MomCozyTypography.captionSize,
                height: 1.6,
              ),
            ),
          ),
        _surface(
          _stack([
            Text(
              '这次最想解决什么？',
              style: MomHomeTokens.text(22, weight: FontWeight.w700),
            ),
            Text(
              '可多选',
              style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
            ),
            _symptoms(),
            _text(
              'goal',
              '希望咨询后有什么变化？',
              controller.goal,
              (v) => controller.goal = v,
              hint: '例如：减少含乳疼痛，找到合适的喂养节奏',
              lines: 2,
              max: 1000,
            ),
          ]),
          padding: 16,
          color: const Color(0xFFFBECE8),
        ),
        const SizedBox(height: 14),
        _disclosure(
          '补充情况',
          controller.support.isEmpty ? '可选' : '已填写',
          _stack([
            const Text(
              '可以补充近期体重、黄疸、用药，或近 24 小时喂养与泵奶情况。',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: MomHomeTokens.secondary,
              ),
            ),
            _text(
              'support',
              '还想让 IBCLC 知道什么？',
              controller.support,
              (v) => controller.support = v,
              lines: 3,
              max: 3000,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _disclosure(
          '基础信息',
          controller.profileReady ? '已预填，可修改' : '需完善',
          _profile(),
          key: ValueKey('profile-${controller.draftRevision}'),
          expanded: !controller.profileReady,
        ),
        const SizedBox(height: 14),
        _surface(
          _stack([
            Text(
              '信息使用',
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            TextButton(onPressed: _consentInfo, child: const Text('查看说明')),
            const Divider(height: 1),
            CheckboxListTile(
              key: const ValueKey('intake-consent'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: MomHomeTokens.rose,
              value: controller.consent,
              onChanged: controller.canEdit
                  ? (v) =>
                        controller.change(() => controller.consent = v ?? false)
                  : null,
              title: const Text(
                '允许本次服务的 IBCLC 查看此表',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ], gap: 8),
        ),
        const SizedBox(height: 14),
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
          onPressed: controller.canSubmit ? _save : null,
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

  Widget _stack(List<Widget> children, {double gap = 14}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );

  Widget _surface(
    Widget child, {
    double padding = 16,
    Color color = MomHomeTokens.surface,
  }) => MomSettingsCard(
    color: color,
    padding: EdgeInsets.all(padding),
    children: [child],
  );

  Widget _disclosure(
    String title,
    String status,
    Widget child, {
    Key? key,
    bool expanded = false,
  }) => _surface(
    ExpansionTile(
      key: key,
      initiallyExpanded: expanded,
      maintainState: true,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.all(16),
      title: MediaQuery.textScalerOf(context).scale(1) > 1.4
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MomHomeTokens.text(15, weight: FontWeight.w700),
                ),
                Text(
                  status,
                  style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: MomHomeTokens.text(15, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                ),
              ],
            ),
      children: [child],
    ),
    padding: 0,
  );

  Widget _symptoms() => LayoutBuilder(
    builder: (context, box) {
      final columns = MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 1 : 2;
      final width = (box.maxWidth - 8 * (columns - 1)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in intakeSymptomLabels.entries)
            SizedBox(
              width: width,
              child: Semantics(
                selected: controller.symptoms.contains(e.key),
                child: OutlinedButton(
                  onPressed: controller.canEdit
                      ? () => controller.toggleSymptom(e.key)
                      : null,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    backgroundColor: controller.symptoms.contains(e.key)
                        ? MomHomeTokens.mint
                        : MomHomeTokens.surface,
                    foregroundColor: controller.symptoms.contains(e.key)
                        ? MomHomeTokens.rose
                        : MomHomeTokens.secondary,
                    side: BorderSide(
                      color: controller.symptoms.contains(e.key)
                          ? MomHomeTokens.rose
                          : MomHomeTokens.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.value,
                          style: MomHomeTokens.text(
                            13,
                            weight: FontWeight.w600,
                            color: !controller.canEdit
                                ? MomHomeTokens.secondary.withValues(alpha: .4)
                                : controller.symptoms.contains(e.key)
                                ? MomHomeTokens.rose
                                : MomHomeTokens.ink,
                          ),
                        ),
                      ),
                      if (controller.symptoms.contains(e.key))
                        const Icon(Icons.check, size: 13),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _label(String label, Widget field) => _stack([
    Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: MomHomeTokens.secondary,
      ),
    ),
    field,
  ], gap: 6);

  String get _postpartumLabel {
    final days = int.tryParse(controller.postpartumDays);
    if (days == null || days < 0) return '产后天数';
    final parts = formatPostpartumDay(days).split(' · ');
    return '产后天数${parts.length > 1 ? ' · ${parts.last}' : ''}';
  }

  Widget _profile() => LayoutBuilder(
    builder: (context, box) {
      final c = controller;
      final columns =
          box.maxWidth >= 320 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.4
          ? 2
          : 1;
      final width = (box.maxWidth - (columns - 1) * 11) / columns;
      final textStyle = Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontSize: 13);
      final fields = [
        _label(
          '当前所在州',
          DropdownButtonFormField<String>(
            initialValue: c.region,
            isExpanded: true,
            itemHeight: null,
            style: textStyle,
            items: {'CA', 'NY', 'TX', if (c.region != null) c.region!}
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(switch (v) {
                      'CA' => 'California (CA)',
                      'NY' => 'New York (NY)',
                      'TX' => 'Texas (TX)',
                      _ => v,
                    }),
                  ),
                )
                .toList(),
            onChanged: c.canEdit ? (v) => c.change(() => c.region = v) : null,
          ),
        ),
        _text(
          'postpartum',
          _postpartumLabel,
          c.postpartumDays,
          (v) => c.postpartumDays = v,
          numeric: true,
        ),
        _text('baby-name', '宝宝称呼', c.babyName, (v) => c.babyName = v, max: 120),
        _label(
          '宝宝出生日期',
          TextFormField(
            key: ValueKey('birth-${c.babyBirthDate}'),
            initialValue: c.babyBirthDate?.toString() ?? '',
            readOnly: true,
            enabled: c.canEdit,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
              suffixIconConstraints: BoxConstraints(minWidth: 28),
            ),
            onTap: _birthDate,
          ),
        ),
        _label(
          '出生记录性别',
          DropdownButtonFormField<BabySex>(
            initialValue: c.babySex,
            isExpanded: true,
            itemHeight: null,
            style: textStyle,
            items: const [
              DropdownMenuItem(
                value: BabySex.unspecified,
                enabled: false,
                child: Text('请选择'),
              ),
              DropdownMenuItem(value: BabySex.female, child: Text('女宝宝')),
              DropdownMenuItem(value: BabySex.male, child: Text('男宝宝')),
            ],
            onChanged: c.canEdit
                ? (v) => c.change(() => c.babySex = v ?? BabySex.unspecified)
                : null,
          ),
        ),
        _label(
          '宝宝月龄',
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
            decoration: BoxDecoration(
              color: MomHomeTokens.neutralSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              formatBabyAge(c.babyBirthDate, c.today),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MomHomeTokens.secondary,
              ),
            ),
          ),
        ),
      ];
      return _stack([
        if (c.data!.babies.length > 1)
          _label(
            '本次咨询的宝宝',
            DropdownButtonFormField<String>(
              initialValue: c.babyId,
              isExpanded: true,
              itemHeight: null,
              style: textStyle,
              items: c.data!.babies
                  .map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  )
                  .toList(),
              onChanged: c.canEdit ? c.selectBaby : null,
            ),
          ),
        Wrap(
          spacing: 11,
          runSpacing: 11,
          children: [
            for (final field in fields) SizedBox(width: width, child: field),
          ],
        ),
        _label(
          '当前喂养方式',
          DropdownButtonFormField<FeedingMode>(
            initialValue: c.feedingMode,
            isExpanded: true,
            itemHeight: null,
            style: textStyle,
            items: feedingModeLabels.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    enabled: e.key != FeedingMode.unknown,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: c.canEdit
                ? (v) =>
                      c.change(() => c.feedingMode = v ?? FeedingMode.unknown)
                : null,
          ),
        ),
      ], gap: 11);
    },
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
  }) => _label(
    label,
    TextFormField(
      key: ValueKey('$key-${controller.draftRevision}'),
      initialValue: value,
      style: MomHomeTokens.text(13),
      enabled: controller.canEdit,
      maxLines: lines,
      maxLength: max,
      keyboardType: numeric
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        alignLabelWithHint: true,
        counterText: '',
      ),
      onChanged: (value) => controller.change(() => changed(value)),
    ),
  );
  Future<void> _birthDate() async {
    final today = controller.today;
    final birth = controller.babyBirthDate;
    final current = birth == null || birth.compareTo(today) > 0 ? today : birth;
    final date = await showMomCozyDatePicker(
      context: context,
      theme: momSettingsTheme(Theme.of(context)),
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
    animationStyle: MomCozyMotion.animationStyle(context),
    builder: (context) => Theme(
      data: momSettingsTheme(Theme.of(context)),
      child: MomSettingsFlowDialog(
        title: '信息使用说明',
        closeLabel: '关闭信息使用说明',
        maxHeight: 720,
        onClose: () => Navigator.pop(context),
        child: _stack([
          for (final item in {
            '提供给谁': '本次服务中被分配的 IBCLC',
            '包含什么': '本页填写内容与确认后的基础信息',
            '用于什么': '咨询前了解情况与准备咨询',
          }.entries)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: MomHomeTokens.border)),
              ),
              child: _stack([
                Text(
                  item.key,
                  style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
                ),
                Text(
                  item.value,
                  style: MomHomeTokens.text(14, weight: FontWeight.w600),
                ),
              ], gap: 8),
            ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ], gap: 0),
      ),
    ),
  );
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final firstSubmission = controller.saved == null;
    final result = await controller.save();
    if (result == null || !mounted) return;
    if (!firstSubmission) {
      widget.onBack();
      return;
    }
    final appointment = controller.data!.appointment;
    final preconsult = await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      barrierDismissible: false,
      builder: (context) => Theme(
        data: momSettingsTheme(Theme.of(context)),
        child: MomSettingsFlowDialog(
          title: '信息采集已完成',
          closeLabel: '关闭信息采集结果',
          showClose: false,
          onClose: null,
          maxHeight: 720,
          child: _stack([
            const Center(
              child: CircleAvatar(
                radius: 21,
                backgroundColor: MomHomeTokens.mint,
                child: Icon(Icons.check, color: MomHomeTokens.teal),
              ),
            ),
            MomAppointmentSummary(appointment: appointment),
            const Text(
              'Cozymate 会结合你填写的信息，进一步了解本次咨询重点，并将重点同步给 IBCLC。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: MomHomeTokens.secondary,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('开始预问诊'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('稍后再说，查看预约'),
            ),
          ]),
        ),
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
