import '../../../features/notifications/presentation/appointment_reminder_tile.dart';
import '../../../features/notifications/presentation/notification_scope.dart';
import '../../../features/notifications/presentation/notification_permission_dialogs.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/date_time_picker.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/zoned_time.dart';
import '../application/booking_controller.dart';
import 'mom_appointment_widgets.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import 'appointment_cancel_dialog.dart';
import 'booking_flow_dialogs.dart';
import 'service_flow_theme.dart';

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
  bool _wantsReminder = false, _flowOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => controller.tick(),
    );
    unawaited(_load());
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
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final current = controller.activeAppointment;
      final confirmed =
          current?.status == AppointmentStatus.confirmed ||
          current?.status == AppointmentStatus.inProgress;
      return Theme(
        data: momSettingsTheme(Theme.of(context)),
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 96
                : 56,
            leadingWidth: MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? 88
                : 64,
            centerTitle: false,
            leading: TextButton(
              onPressed: controller.busy ? null : widget.onBack,
              child: const Text('返回'),
            ),
            title: Text(confirmed ? '预约详情' : '选择时间'),
            actions: [
              IconButton(
                tooltip: '刷新预约',
                onPressed: controller.busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: ClipRect(
            child: MomCozyPageBody(child: _body(current, confirmed)),
          ),
        ),
      );
    },
  );

  Widget _body(CareAppointment? current, bool confirmed) {
    if (controller.loading && controller.data == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MomSettingsCard(
          children: [
            Text(
              '正在加载预约…',
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            const LinearProgressIndicator(),
          ],
        ),
      );
    }
    if (controller.loadFailure case final failure?) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ProductErrorView(failure: failure, onRetry: _load),
      );
    }
    final data = controller.data;
    if (data == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (controller.failure != null || controller.message != null)
            _failure(),
          if (controller.unresolvedMutation) ...[
            const Text(
              '正在核对上次提交结果，请重试以恢复预约。',
              style: TextStyle(color: MomHomeTokens.secondary),
            ),
            const SizedBox(height: MomCozySpacing.compact),
            FilledButton(
              onPressed: controller.busy ? null : _retry,
              child: Text(controller.busy ? '正在确认…' : '重试上次提交'),
            ),
            const SizedBox(height: MomCozySpacing.card),
          ],
          if (current?.status == AppointmentStatus.held) ...[
            _picker(),
            const SizedBox(height: 16),
            for (final slot
                in controller.availability?.slots ??
                    [
                      AppointmentSlot(
                        startsAt: current!.startsAt,
                        endsAt: current.endsAt,
                        available: true,
                      ),
                    ])
              _slot(slot),
            TextButton(
              onPressed: controller.busy ? null : _reviewHold,
              child: const Text('查看所选时间'),
            ),
          ] else if (current != null) ...[
            MomAppointmentSummary(
              appointment: current,
              title: current.status == AppointmentStatus.inProgress
                  ? '咨询中 · IBCLC 咨询'
                  : confirmed
                  ? '已确认 · IBCLC 咨询'
                  : '所选时间已暂时保留',
              action: current.status == AppointmentStatus.confirmed
                  ? OutlinedButton(
                      onPressed: controller.canEdit ? _cancel : null,
                      style: ServiceFlowTheme.cancellationStyle(
                        context,
                        tinted: true,
                      ),
                      child: const Text('取消预约'),
                    )
                  : null,
            ),
            const SizedBox(height: MomCozySpacing.card),
            MomSettingsCard(
              children: [
                Text(
                  '咨询前准备',
                  style: MomHomeTokens.text(18, weight: FontWeight.w700),
                ),
                const Text(
                  '咨询前请完成信息采集表，让专家了解这次最想解决的问题。',
                  style: TextStyle(height: 1.6),
                ),
                FilledButton(
                  onPressed: controller.canEdit
                      ? () => _openIntake(current)
                      : null,
                  child: Text(
                    current.intakeVersion > 0 ? '查看信息采集表' : '填写信息采集表',
                  ),
                ),
                if (widget.onConsultation != null) ...[
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
              ],
            ),
            const SizedBox(height: 14),
            if (current.status == AppointmentStatus.confirmed)
              MomSettingsCard(
                children: [
                  AppointmentReminderTile(
                    key: ValueKey('${current.id}-${current.version}'),
                    appointmentId: current.id,
                  ),
                ],
              ),
          ] else if (!data.episode.canBook)
            MomSettingsCard(
              children: [
                Text(
                  '当前没有可用的咨询次数',
                  style: MomHomeTokens.text(18, weight: FontWeight.w700),
                ),
                Text(
                  '可在服务进度中查看已完成的咨询。',
                  style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
                ),
              ],
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${controller.availability?.slots.length ?? 0} 个时段',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MomHomeTokens.secondary,
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
              MomSettingsCard(
                children: [
                  Text(
                    '暂无可选时间',
                    style: MomHomeTokens.text(16, weight: FontWeight.w700),
                  ),
                  Text(
                    '请尝试其他日期或专家。',
                    style: MomHomeTokens.text(
                      13,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                ],
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

  Widget _precheck() => MomSettingsCard(
    gradient: MomHomeTokens.milk,
    children: [
      Text('先做个预约前确认', style: MomHomeTokens.text(22, weight: FontWeight.w700)),
      Text(
        '确认所在州、服务适用性与紧急风险。',
        style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
      ),
      FilledButton(
        onPressed: controller.canEdit ? _reviewPrecheck : null,
        child: const Text('开始确认'),
      ),
    ],
  );

  Widget _picker() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MomSettingsCard(
        color: MomHomeTokens.mint,
        children: [
          Text('选择专家', style: MomHomeTokens.text(18, weight: FontWeight.w700)),
          if (controller.provider case final provider?)
            MomServiceExpertIdentity(
              name: provider.displayName,
              label: '可预约专家',
              bio: provider.bio,
            ),
          DropdownButtonFormField<String>(
            key: ValueKey(controller.providerId),
            initialValue: controller.providerId,
            isExpanded: true,
            itemHeight: null,
            style: MomHomeTokens.text(13),
            items: controller.providers
                .map(
                  (p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.displayName)),
                )
                .toList(),
            onChanged: controller.canChoose ? controller.selectProvider : null,
          ),
          if (controller.provider case final provider?)
            Text(
              '以下时间均为 ${provider.timezone}',
              style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
            ),
        ],
      ),
      const SizedBox(height: 14),
      MomSettingsCard(
        children: [
          Text(
            '日期',
            style: MomHomeTokens.text(
              12,
              weight: FontWeight.w700,
              color: MomHomeTokens.secondary,
            ),
          ),
          OutlinedButton(
            onPressed: controller.canChoose ? _selectDate : null,
            child: Row(
              children: [
                Expanded(child: Text(controller.date.toString())),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today_outlined, size: 18),
              ],
            ),
          ),
          if (controller.date case final date?)
            Text(
              '${date == controller.today ? '今天 · ' : ''}${['周一', '周二', '周三', '周四', '周五', '周六', '周日'][DateTime(date.year, date.month, date.day).weekday - 1]}',
              style: MomHomeTokens.text(11, color: MomHomeTokens.secondary),
            ),
        ],
      ),
    ],
  );

  Widget _slot(AppointmentSlot slot) {
    final current = controller.activeAppointment;
    final selected =
        current?.status == AppointmentStatus.held &&
        current?.startsAt == slot.startsAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? MomCozyColors.roseSoft
            : slot.available
            ? MomHomeTokens.surface
            : MomHomeTokens.neutralSurface,
        borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
          onTap: selected
              ? _reviewHold
              : controller.canChoose && slot.available
              ? () => _hold(slot)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: MomHomeTokens.border),
              borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
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
                          controller.provider?.timezone ??
                              current?.timezone ??
                              'UTC',
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: slot.available
                              ? MomHomeTokens.ink
                              : MomHomeTokens.secondary,
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.xs),
                      Text(
                        '${slot.duration.inMinutes} 分钟${slot.available ? '' : ' · 已占用'}',
                        style: const TextStyle(
                          color: MomHomeTokens.secondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MomCozySpacing.statusGap),
                Icon(
                  selected
                      ? Icons.check_circle
                      : slot.available
                      ? Icons.radio_button_unchecked
                      : Icons.block,
                  color: MomHomeTokens.secondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    await controller.load();
    if (!mounted || _flowOpen || controller.loadFailure != null) return;
    if (controller.activeAppointment?.status == AppointmentStatus.held) {
      await _reviewHold();
    } else if (controller.activeAppointment == null &&
        (controller.data?.episode.canBook ?? false) &&
        !controller.precheckReady) {
      await _reviewPrecheck();
    }
  }

  Future<void> _reviewPrecheck() async {
    if (_flowOpen || !mounted) return;
    _flowOpen = true;
    try {
      await showDialog<bool>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        barrierDismissible: false,
        builder: (_) => BookingPrecheckDialog(controller: controller),
      );
    } finally {
      _flowOpen = false;
    }
  }

  Future<void> _reviewHold() async {
    final appointment = controller.activeAppointment;
    if (_flowOpen ||
        !mounted ||
        appointment?.status != AppointmentStatus.held) {
      return;
    }
    _flowOpen = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (context, update) => BookingSelectionDialog(
            controller: controller,
            appointment: appointment!,
            reminder: _wantsReminder,
            onReminderChanged: (v) => update(() => _wantsReminder = v),
          ),
        ),
      );
    } finally {
      _flowOpen = false;
    }
    if (confirmed == true && mounted) await _afterConfirmed();
  }

  Future<void> _hold(AppointmentSlot slot) async {
    await controller.hold(slot);
    if (mounted) await _reviewHold();
  }

  Future<void> _retry() async {
    await controller.retry();
    if (!mounted) return;
    if (controller.activeAppointment?.status == AppointmentStatus.confirmed) {
      await _afterConfirmed();
    } else {
      await _reviewHold();
    }
  }

  Future<void> _selectDate() async {
    final today = controller.today,
        selected = controller.date ?? today,
        end = today.addDays(90);
    final value = await showMomCozyDatePicker(
      context: context,
      theme: momSettingsTheme(Theme.of(context)),
      initialDate: DateTime(selected.year, selected.month, selected.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(end.year, end.month, end.day),
    );
    if (value != null && mounted) {
      await controller.selectDate(LocalDate.fromDateTime(value));
    }
  }

  Future<void> _afterConfirmed() async {
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
    final appointment = controller.activeAppointment;
    if (_flowOpen || appointment?.status != AppointmentStatus.confirmed) return;
    _flowOpen = true;
    final cancelled = await showAppointmentCancellation(
      context,
      repository: widget.repository,
      appointment: appointment!,
    );
    _flowOpen = false;
    if (!mounted) return;
    if (cancelled != null) {
      widget.onBack();
    } else {
      await controller.load();
    }
  }
}
