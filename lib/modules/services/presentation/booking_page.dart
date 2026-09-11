import '../../../features/notifications/presentation/appointment_reminder_tile.dart';
import '../../../features/notifications/presentation/notification_scope.dart';
import '../../../features/notifications/presentation/notification_permission_dialogs.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/zoned_time.dart';
import '../application/booking_controller.dart';
import 'appointment_summary.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({
    super.key,
    required this.repository,
    required this.episodeId,
    required this.onBack,
    required this.onIntake,
    this.onConsultation,
    this.now,
  });
  final AppointmentRepository repository;
  final String episodeId;
  final VoidCallback onBack;
  final Future<void> Function(CareAppointment) onIntake;
  final Future<void> Function(CareAppointment)? onConsultation;
  final DateTime Function()? now;
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> with WidgetsBindingObserver {
  late final controller = BookingController(
    repository: widget.repository,
    episodeId: widget.episodeId,
    now: widget.now,
  );
  Timer? _timer;
  bool _wantsReminder = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => controller.tick(),
    );
    unawaited(controller.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.load());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final current = controller.activeAppointment;
      final confirmed =
          current?.status == AppointmentStatus.confirmed ||
          current?.status == AppointmentStatus.inProgress;
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: widget.onBack),
          title: Text(confirmed ? '预约详情' : '选择时间'),
          actions: [
            IconButton(
              tooltip: '刷新预约',
              onPressed: controller.busy ? null : controller.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: MomCozyPageBody(child: _body(current, confirmed)),
      );
    },
  );

  Widget _body(CareAppointment? current, bool confirmed) {
    if (controller.loading && controller.data == null) {
      return const ProductLoadingView();
    }
    if (controller.loadFailure case final failure?) {
      return ProductErrorView(failure: failure, onRetry: controller.load);
    }
    final data = controller.data;
    if (data == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: MomCozyInsets.page,
        children: [
          if (controller.failure != null || controller.message != null)
            _failure(),
          if (controller.unresolvedMutation) ...[
            const Text(
              '正在核对上次提交结果，请重试以恢复预约。',
              style: TextStyle(color: MomCozyColors.mutedForeground),
            ),
            const SizedBox(height: MomCozySpacing.compact),
            FilledButton(
              onPressed: controller.busy ? null : controller.retry,
              child: Text(controller.busy ? '正在确认…' : '重试上次提交'),
            ),
            const SizedBox(height: MomCozySpacing.card),
          ],
          if (current != null) ...[
            AppointmentSummary(
              appointment: current,
              title: confirmed ? '已确认的咨询' : '所选时间已暂时保留',
            ),
            const SizedBox(height: MomCozySpacing.card),
            if (current.status == AppointmentStatus.confirmed)
              AppointmentReminderTile(
                key: ValueKey('${current.id}-${current.version}'),
                appointmentId: current.id,
              ),
            if (current.status == AppointmentStatus.held) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me 15 minutes before'),
                subtitle: const Text(
                  'We’ll check notification permission before enabling your reminder.',
                ),
                value: _wantsReminder,
                onChanged: controller.canEdit
                    ? (value) => setState(() => _wantsReminder = value ?? false)
                    : null,
              ),
              Text(
                '请在 ${_remaining(current)} 内确认',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MomCozyColors.mutedForeground,
                  fontSize: MomCozyTypography.captionSize,
                ),
              ),
              const SizedBox(height: MomCozySpacing.content),
              FilledButton(
                onPressed: controller.canEdit ? _confirm : null,
                child: Text(controller.busy ? '正在确认…' : '确认预约'),
              ),
              TextButton(
                onPressed: controller.canEdit ? controller.cancel : null,
                child: const Text('重新选择'),
              ),
            ] else ...[
              const Text(
                '咨询前请完成信息采集表，让专家了解这次最想解决的问题。',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: MomCozySpacing.page),
              FilledButton(
                onPressed: controller.canEdit
                    ? () => _openIntake(current)
                    : null,
                child: Text(current.intakeVersion > 0 ? '查看信息采集表' : '填写信息采集表'),
              ),
              if (widget.onConsultation != null) ...[
                const SizedBox(height: MomCozySpacing.content),
                OutlinedButton.icon(
                  onPressed: controller.canEdit
                      ? () async {
                          await widget.onConsultation!(current);
                          await controller.load();
                        }
                      : null,
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(
                    current.status == AppointmentStatus.inProgress
                        ? '返回咨询室'
                        : '咨询前准备',
                  ),
                ),
              ],
              if (current.status == AppointmentStatus.confirmed)
                TextButton(
                  onPressed: controller.canEdit ? _cancel : null,
                  child: const Text(
                    '取消预约',
                    style: TextStyle(color: MomCozyColors.danger),
                  ),
                ),
            ],
          ] else if (!data.episode.canBook)
            const ProductEmptyView(
              title: '当前没有可用的咨询次数',
              description: '可在服务进度中查看已完成的咨询。',
            )
          else if (!controller.precheckReady)
            _precheck()
          else ...[
            _picker(),
            const SizedBox(height: MomCozySpacing.card),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '可选时间',
                    style: TextStyle(
                      fontSize: MomCozyTypography.sectionSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${controller.availability?.slots.length ?? 0} 个时段',
                  style: const TextStyle(
                    fontSize: MomCozyTypography.captionSize,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MomCozySpacing.content),
            if (controller.loadingSlots)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(MomCozySpacing.section),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (controller.availabilityFailure case final failure?)
              ProductErrorView(failure: failure, onRetry: controller.loadSlots)
            else if (controller.availability?.slots.isEmpty ?? true)
              const ProductEmptyView(
                title: '暂无可选时间',
                description: '请尝试其他日期或专家。',
              )
            else
              for (final slot in controller.availability!.slots) _slot(slot),
          ],
        ],
      ),
    );
  }

  Widget _failure() => controller.message == null
      ? ProductErrorView(
          failure: controller.failure!,
          onRetry: controller.unresolvedMutation || controller.busy
              ? null
              : controller.load,
        )
      : Semantics(
          liveRegion: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(MomCozySpacing.headingGap),
            decoration: BoxDecoration(
              color: MomCozyColors.amberSoft,
              borderRadius: BorderRadius.circular(MomCozyRadii.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.message!),
                if (!controller.busy && !controller.unresolvedMutation)
                  TextButton(
                    onPressed: controller.load,
                    child: const Text('刷新预约'),
                  ),
              ],
            ),
          ),
        );

  Widget _precheck() => MomCozySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '预约前确认',
          style: TextStyle(
            fontSize: MomCozyTypography.headingSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MomCozySpacing.section),
        DropdownButtonFormField<String>(
          initialValue: controller.region,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '当前所在州'),
          items: const [
            DropdownMenuItem(value: 'CA', child: Text('California (CA)')),
            DropdownMenuItem(value: 'NY', child: Text('New York (NY)')),
            DropdownMenuItem(value: 'TX', child: Text('Texas (TX)')),
          ],
          onChanged: controller.canEdit ? controller.setRegion : null,
        ),
        const SizedBox(height: MomCozySpacing.section),
        const Text('服务适用性', style: TextStyle(fontWeight: FontWeight.w700)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('我需要的是哺乳或喂养相关的 IBCLC 咨询'),
          value: controller.serviceSuitable,
          onChanged: controller.canEdit
              ? (value) => controller.setSuitable(value ?? false)
              : null,
        ),
        const SizedBox(height: MomCozySpacing.page),
        const Text('紧急风险判断', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: MomCozySpacing.compact),
        const Text(
          '如妈妈或宝宝出现呼吸困难、无法唤醒、大量出血等情况，应先寻求紧急医疗帮助。',
          style: TextStyle(
            color: MomCozyColors.mutedForeground,
            fontSize: MomCozyTypography.secondarySize,
            height: 1.6,
          ),
        ),
        RadioGroup<EmergencyStatus>(
          groupValue: controller.emergencyStatus,
          onChanged: controller.setEmergency,
          child: Column(
            children: [
              RadioListTile(
                value: EmergencyStatus.clear,
                enabled: controller.canEdit,
                contentPadding: EdgeInsets.zero,
                title: const Text('目前没有上述紧急情况'),
              ),
              RadioListTile(
                value: EmergencyStatus.needsHelp,
                enabled: controller.canEdit,
                contentPadding: EdgeInsets.zero,
                title: const Text('有，或我不确定'),
              ),
            ],
          ),
        ),
        if (controller.emergencyStatus == EmergencyStatus.needsHelp)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '请先联系当地急救服务。IBCLC 预约不能替代紧急医疗。',
              style: TextStyle(color: MomCozyColors.danger),
            ),
          ),
        const SizedBox(height: MomCozySpacing.page),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: controller.canPrecheck ? controller.precheck : null,
            child: Text(controller.busy ? '正在确认…' : '继续选择时间'),
          ),
        ),
      ],
    ),
  );

  Widget _picker() => MomCozySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '日期',
          style: TextStyle(
            color: MomCozyColors.mutedForeground,
            fontSize: MomCozyTypography.captionSize,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: controller.canChoose ? _selectDate : null,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(controller.date.toString()),
        ),
        const SizedBox(height: MomCozySpacing.card),
        DropdownButtonFormField<String>(
          key: ValueKey(controller.providerId),
          initialValue: controller.providerId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '选择专家'),
          items: controller.providers
              .map(
                (provider) => DropdownMenuItem(
                  value: provider.id,
                  child: Text(provider.displayName),
                ),
              )
              .toList(),
          onChanged: controller.canChoose ? controller.selectProvider : null,
        ),
        if (controller.provider case final provider?) ...[
          const SizedBox(height: MomCozySpacing.headingGap),
          const Text(
            'IBCLC · 哺乳顾问',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: MomCozyTypography.secondarySize,
            ),
          ),
          if (provider.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                provider.bio,
                style: const TextStyle(
                  fontSize: MomCozyTypography.captionSize,
                  color: MomCozyColors.mutedForeground,
                ),
              ),
            ),
          const SizedBox(height: MomCozySpacing.statusGap),
          Text(
            '以下时间均为 ${provider.timezone}',
            style: const TextStyle(
              fontSize: MomCozyTypography.labelSize,
              color: MomCozyColors.mutedForeground,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _slot(AppointmentSlot slot) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: slot.available ? MomCozyColors.raised : MomCozyColors.secondary,
      borderRadius: BorderRadius.circular(MomCozyRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(MomCozyRadii.card),
        onTap: controller.canChoose && slot.available
            ? () => controller.hold(slot)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: MomCozyColors.border),
            borderRadius: BorderRadius.circular(MomCozyRadii.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zonedRange(
                        slot.startsAt,
                        slot.endsAt,
                        controller.provider!.timezone,
                      ),
                      style: TextStyle(
                        fontSize: MomCozyTypography.bodyLargeSize,
                        fontWeight: FontWeight.w600,
                        color: slot.available
                            ? MomCozyColors.foreground
                            : MomCozyColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: MomCozySpacing.xs),
                    Text(
                      '${slot.duration.inMinutes} 分钟${slot.available ? '' : ' · 已占用'}',
                      style: const TextStyle(
                        color: MomCozyColors.mutedForeground,
                        fontSize: MomCozyTypography.captionSize,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MomCozySpacing.statusGap),
              Icon(
                slot.available ? Icons.radio_button_unchecked : Icons.block,
                color: MomCozyColors.mutedForeground,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String _remaining(CareAppointment appointment) {
    final seconds = appointment.holdExpiresAt
        .difference(controller.now)
        .inSeconds
        .clamp(0, 600);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final today = controller.today,
        selected = controller.date ?? today,
        end = today.addDays(90);
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime(selected.year, selected.month, selected.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(end.year, end.month, end.day),
    );
    if (value != null && mounted) {
      await controller.selectDate(LocalDate.fromDateTime(value));
    }
  }

  Future<void> _confirm() async {
    await controller.confirm();
    if (!mounted) return;
    final appointment = controller.activeAppointment;
    if (appointment?.status == AppointmentStatus.confirmed) {
      if (_wantsReminder) {
        final coordinator = NotificationScope.maybeOf(context);
        if (coordinator != null) {
          await coordinator.setReminder(
            appointment!.id,
            enabled: true,
            explain: () => explainNotifications(context),
            offerSettings: () => offerNotificationSettings(context),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your appointment is saved. Background reminders are unavailable on this device.',
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      await _openIntake(appointment!);
    }
  }

  Future<void> _openIntake(CareAppointment appointment) async {
    await widget.onIntake(appointment);
    if (mounted) await controller.load();
  }

  Future<void> _cancel() async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消预约'),
        content: const Text('取消后，该时段将释放。重新预约时需要再次确认信息采集表，已填写内容会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留预约'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '确认取消',
              style: TextStyle(color: MomCozyColors.danger),
            ),
          ),
        ],
      ),
    );
    if (cancel == true && mounted) await controller.cancel();
  }
}
