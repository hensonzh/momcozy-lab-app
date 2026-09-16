import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../services/consultations/consultation_media.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/zoned_time.dart';
import '../../services/presentation/appointment_summary.dart';
import '../../services/presentation/mom_appointment_widgets.dart';
import '../application/room_controller.dart';
import 'video_stage.dart';
import 'device_check_dialog.dart';
import 'device_preview_dialog.dart';
import 'consultation_start_dialog.dart';
import 'consultation_preparation.dart';
import 'consultation_outcome.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../services/consultations/device_check.dart';

class ConsultationRoomPage extends StatefulWidget {
  const ConsultationRoomPage({
    super.key,
    required this.createController,
    required this.onBack,
    required this.onIntake,
    required this.onProgress,
    required this.onRebook,
    this.onHome,
    this.createDeviceCheck,
    this.onCancel,
    this.overHome = false,
  });
  final bool overHome;
  final ConsultationRoomController Function() createController;
  final ConsultationDeviceCheck Function()? createDeviceCheck;
  final Future<void> Function(CareAppointment)? onCancel;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final Future<void> Function() onIntake;
  final void Function(CareAppointment) onProgress, onRebook;
  @override
  State<ConsultationRoomPage> createState() => _ConsultationRoomPageState();
}

class _ConsultationRoomPageState extends State<ConsultationRoomPage>
    with WidgetsBindingObserver {
  late final ConsultationRoomController controller = widget.createController();
  Timer? _timer;
  bool _allowPop = false, _leaving = false, _flowOpen = false;
  bool _leaveFailed = false;
  final _leaveFailureKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(controller.load()),
    );
    unawaited(controller.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_leaving ||
        (!controller.isExpert &&
            (_flowOpen || (controller.busy && !controller.inRoom)))) {
      return;
    }
    _leaving = true;
    try {
      if (controller.inRoom || controller.wantsToJoin) {
        final leave = await showDialog<bool>(
          context: context,
          animationStyle: MomCozyMotion.animationStyle(context),
          builder: (context) => !controller.isExpert
              ? _leaveConfirmation(context)
              : AlertDialog(
                  scrollable: true,
                  title: const Text('暂时离开咨询室？'),
                  content: const Text('离开不会结束咨询，你可以从预约详情重新进入。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('留在房间'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('暂时离开'),
                    ),
                  ],
                ),
        );
        if (leave != true) {
          return;
        }
      }
      if (!mounted) return;
      if (_leaveFailed) setState(() => _leaveFailed = false);
      try {
        await controller.leave();
      } catch (_) {
        if (mounted) {
          setState(() => _leaveFailed = true);
          await WidgetsBinding.instance.endOfFrame;
          final noticeContext = _leaveFailureKey.currentContext;
          if (mounted && noticeContext != null && noticeContext.mounted) {
            await Scrollable.ensureVisible(noticeContext);
          }
        }
        return;
      }
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) widget.onBack();
    } finally {
      _leaving = false;
    }
  }

  Widget _leaveConfirmation(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: MomSettingsFlowDialog(
      title: '暂时离开咨询室？',
      closeLabel: '关闭离开确认',
      onClose: () => Navigator.pop(context, false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '离开不会结束咨询，你可以从预约详情重新进入。',
            style: MomHomeTokens.text(
              13,
              height: 1.55,
              color: MomHomeTokens.secondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('留在房间'),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('暂时离开'),
          ),
        ],
      ),
    ),
  );

  bool get _isUserRoomContent =>
      !controller.isExpert &&
      controller.data != null &&
      (controller.data!.ended || controller.inRoom);

  AppBar _userRoomAppBar() => AppBar(
    backgroundColor: MomHomeTokens.background,
    surfaceTintColor: Colors.transparent,
    toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 72 : 64,
    leading: IconButton(
      tooltip: '返回',
      onPressed: _back,
      color: MomHomeTokens.rose,
      icon: const Icon(Icons.chevron_left),
    ),
    centerTitle: false,
    title: Text('视频咨询', style: MomHomeTokens.text(20, weight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope(
      canPop:
          _allowPop ||
          ((controller.isExpert || (!_flowOpen && !controller.busy)) &&
              !controller.inRoom &&
              !controller.wantsToJoin),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child:
          widget.overHome &&
              !controller.isExpert &&
              !controller.inRoom &&
              !(controller.data?.ended ?? false)
          ? Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: _flowOpen
                    ? const SizedBox.shrink()
                    : controller.data == null
                    ? _preparationDialog(
                        onClose: _back,
                        child: controller.failure == null
                            ? MomSettingsCard(
                                children: [
                                  Text(
                                    '正在载入',
                                    style: MomHomeTokens.text(
                                      16,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const LinearProgressIndicator(),
                                ],
                              )
                            : ProductErrorView(
                                failure: controller.failure!,
                                onRetry: controller.load,
                              ),
                      )
                    : _userPreparation(controller.data!),
              ),
            )
          : Scaffold(
              backgroundColor: _isUserRoomContent
                  ? MomHomeTokens.background
                  : null,
              appBar: _isUserRoomContent
                  ? _userRoomAppBar()
                  : !controller.isExpert &&
                        controller.data != null &&
                        !controller.data!.ended &&
                        !controller.inRoom
                  ? null
                  : AppBar(
                      toolbarHeight: controller.isExpert ? kToolbarHeight : 52,
                      leadingWidth: controller.isExpert
                          ? null
                          : MediaQuery.textScalerOf(context).scale(1) > 1.4
                          ? 88
                          : 64,
                      leading: controller.isExpert
                          ? BackButton(onPressed: _back)
                          : TextButton(
                              onPressed: _back,
                              style: TextButton.styleFrom(
                                foregroundColor: MomCozyColors.mutedForeground,
                              ),
                              child: const Text('返回'),
                            ),
                      centerTitle: !controller.isExpert,
                      title: Text(
                        '视频咨询',
                        style: controller.isExpert
                            ? null
                            : const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                      ),
                      bottom: controller.isExpert
                          ? null
                          : const PreferredSize(
                              preferredSize: Size.fromHeight(1),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(height: 1),
                              ),
                            ),
                      actions: [
                        if (controller.isExpert)
                          IconButton(
                            tooltip: '刷新咨询状态',
                            onPressed: controller.busy ? null : controller.load,
                            icon: const Icon(Icons.refresh),
                          ),
                      ],
                    ),
              body:
                  !controller.isExpert &&
                      controller.data != null &&
                      !controller.data!.ended &&
                      !controller.inRoom
                  ? _userPreparation(controller.data!)
                  : MomCozyPageBody(
                      maxWidth: controller.isExpert
                          ? 760
                          : MomCozyLayout.maxAppWidth,
                      child: _body(),
                    ),
            ),
    ),
  );
  Widget _preparationDialog({
    required VoidCallback? onClose,
    required Widget child,
  }) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: MomSettingsFlowDialog(
      title: '预约详情',
      closeLabel: '关闭预约详情',
      onClose: onClose,
      child: child,
    ),
  );

  Widget _userPreparation(ConsultationRoomContext data) => _preparationDialog(
    onClose: _flowOpen || controller.busy ? null : _back,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.message case final message?) _notice(message),
        if (controller.failure != null)
          TextButton(
            onPressed: controller.busy || _flowOpen ? null : controller.load,
            child: const Text('刷新咨询状态'),
          ),
        if (controller.pendingEnd)
          TextButton(
            onPressed: controller.busy ? null : controller.retryEnd,
            child: const Text('核对结束咨询的结果'),
          ),
        ConsultationPreparation(
          data: data,
          now: () => controller.now,
          busy: controller.busy || _flowOpen || controller.pendingEnd,
          onStart: _startConsultation,
          onIntake: () async {
            await widget.onIntake();
            if (mounted) await controller.load();
          },
          onRebook: () => widget.onRebook(data.appointment),
          onCancel:
              widget.onCancel != null &&
                  !data.active &&
                  data.appointment.status == AppointmentStatus.confirmed
              ? () => _cancelAppointment(data.appointment)
              : null,
        ),
      ],
    ),
  );

  Future<void> _cancelAppointment(CareAppointment appointment) async {
    if (_flowOpen || controller.busy) return;
    setState(() => _flowOpen = true);
    try {
      await widget.onCancel!(appointment);
      if (mounted) await controller.load();
    } finally {
      if (mounted) setState(() => _flowOpen = false);
    }
  }

  Widget _body() {
    if (controller.loading && controller.data == null) {
      return const ProductLoadingView();
    }
    final data = controller.data;
    if (data == null) {
      return controller.failure == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: MomCozyInsets.page,
              child: ProductErrorView(
                failure: controller.failure!,
                onRetry: controller.load,
              ),
            );
    }
    if (!controller.isExpert && data.ended) {
      return Theme(
        data: momSettingsTheme(Theme.of(context)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_leaveFailed) ...[
                  _leaveFailureNotice(),
                  const SizedBox(height: 14),
                ],
                if (controller.message case final message?) ...[
                  _sessionNotice(message),
                  const SizedBox(height: 14),
                ],
                if (controller.pendingEnd) ...[
                  FilledButton(
                    onPressed: controller.busy ? null : controller.retryEnd,
                    child: const Text('核对结束咨询的结果'),
                  ),
                  const SizedBox(height: 14),
                ],
                UserConsultationOutcome(
                  data: data,
                  onSummary: () => widget.onProgress(data.appointment),
                  onRebook: () => widget.onRebook(data.appointment),
                  onHome: widget.onHome ?? widget.onBack,
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (!controller.isExpert && controller.inRoom && !data.ended) {
      return _userSession(data);
    }
    return ListView(
      padding: MomCozyInsets.page,
      children: [
        if (_leaveFailed) _leaveFailureNotice(),
        if (controller.message case final message?) _notice(message),
        if (controller.pendingEnd)
          FilledButton(
            onPressed: controller.busy ? null : controller.retryEnd,
            child: const Text('核对结束咨询的结果'),
          ),
        if (data.ended)
          _outcome(data)
        else if (!controller.inRoom)
          _expertPreparation(data)
        else ...[
          _sessionHeader(data),
          const SizedBox(height: MomCozySpacing.headingGap),
          ConsultationVideoStage(data: data, media: controller.media),
          if (controller.media.error case final error?) _notice(error),
          if (controller.media.weakNetwork) _notice('网络较弱，音视频可能暂时不流畅。'),
          if (controller.media.audioPlaybackBlocked)
            TextButton(
              onPressed: controller.media.enableAudio,
              child: const Text('点击开启通话声音'),
            ),
          const SizedBox(height: MomCozySpacing.content),
          ConsultationMediaControls(media: controller.media, onLeave: _back),
          if (controller.media.state ==
              ConsultationMediaState.disconnected) ...[
            const SizedBox(height: MomCozySpacing.content),
            FilledButton(
              onPressed: controller.canEnter ? controller.enter : null,
              child: const Text('重新连接'),
            ),
            TextButton(
              onPressed: controller.busy ? null : controller.leave,
              child: const Text('返回咨询准备'),
            ),
          ],
          if (controller.isExpert) _expertActions(data),
        ],
      ],
    );
  }

  Widget _userSession(ConsultationRoomContext data) {
    final media = controller.media;
    final reconnecting = media.state == ConsultationMediaState.reconnecting;
    return Theme(
      data: momSettingsTheme(Theme.of(context)),
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_leaveFailed) ...[
                  _leaveFailureNotice(),
                  const SizedBox(height: 14),
                ],
                if (controller.message case final message?) ...[
                  _sessionNotice(message),
                  const SizedBox(height: 14),
                ],
                MomServiceExpertIdentity(
                  name: data.appointment.providerName,
                  label: '本次咨询专家',
                ),
                const SizedBox(height: 8),
                Text(
                  '${appointmentDay(data.appointment.startsAt, data.appointment.timezone)} · ${zonedRange(data.appointment.startsAt, data.appointment.endsAt, data.appointment.timezone)}',
                  style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: MomHomeTokens.mint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      reconnecting
                          ? '重新连接'
                          : data.active
                          ? '咨询中'
                          : '等待室',
                      style: MomHomeTokens.text(
                        11,
                        weight: FontWeight.w700,
                        color: MomHomeTokens.teal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ConsultationVideoStage(data: data, media: media),
                const SizedBox(height: 14),
                if (media.error case final error?) ...[
                  _sessionNotice(error),
                  const SizedBox(height: 14),
                ],
                if (media.weakNetwork) ...[
                  _sessionNotice('网络较弱，音视频可能暂时不流畅。'),
                  const SizedBox(height: 14),
                ],
                if (media.audioPlaybackBlocked) ...[
                  OutlinedButton(
                    onPressed: media.busy ? null : media.enableAudio,
                    child: const Text('点击开启通话声音'),
                  ),
                  const SizedBox(height: 14),
                ],
                ConsultationMediaControls(
                  media: media,
                  onLeave: _back,
                  compact: true,
                ),
                if (media.state == ConsultationMediaState.disconnected) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: controller.canEnter ? controller.enter : null,
                    child: const Text('重新连接'),
                  ),
                  TextButton(
                    onPressed: controller.busy ? null : controller.leave,
                    child: const Text('返回咨询准备'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionNotice(String text) => Semantics(
    liveRegion: true,
    child: MomSettingsCard(
      color: MomCozyColors.amberSoft,
      children: [Text(text, style: MomHomeTokens.text(13, height: 1.55))],
    ),
  );

  Widget _leaveFailureNotice() => KeyedSubtree(
    key: _leaveFailureKey,
    child: _isUserRoomContent
        ? _sessionNotice('暂时无法离开咨询室，请再次点击离开房间重试。')
        : _notice('暂时无法离开咨询室，请再次点击离开房间重试。'),
  );

  Widget _notice(String text) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: MomCozySpacing.headingGap),
      child: MomCozySurface(
        color: MomCozyColors.amberSoft,
        padding: MomCozyInsets.compactCard,
        child: Text(
          text,
          style: const TextStyle(fontSize: MomCozyTypography.secondarySize),
        ),
      ),
    ),
  );
  Widget _expertPreparation(ConsultationRoomContext data) {
    final open = data.windowOpen(controller.now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppointmentSummary(appointment: data.appointment, title: '本次咨询'),
        const SizedBox(height: MomCozySpacing.section),
        const Text(
          '咨询前准备',
          style: TextStyle(
            fontSize: MomCozyTypography.headingSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MomCozySpacing.compact),
        const Text(
          '找一个安静、光线充足的位置，准备好摄像头与麦克风。',
          style: TextStyle(
            color: MomCozyColors.mutedForeground,
            height: MomCozyTypography.lineHeight,
          ),
        ),
        const SizedBox(height: MomCozySpacing.page),
        OutlinedButton.icon(
          onPressed: controller.busy
              ? null
              : () => showDialog<void>(
                  context: context,
                  animationStyle: MomCozyMotion.animationStyle(context),
                  builder: (context) => const ConsultationDevicePreviewDialog(),
                ),
          icon: const Icon(Icons.videocam_outlined),
          label: const Text('检查摄像头与麦克风'),
        ),
        const SizedBox(height: MomCozySpacing.content),
        if (data.videoProvider == VideoProvider.sandbox)
          _notice('当前为模拟咨询，可验证双端流程，不传输远程音视频。'),
        if (data.videoProvider == VideoProvider.disabled)
          _notice('视频咨询暂未开放，请稍后再试。'),
        if (!open)
          _notice(
            controller.now.isBefore(data.opensAt)
                ? '咨询室将在 ${appointmentDay(data.opensAt, data.appointment.timezone)} ${zonedClock(data.opensAt, data.appointment.timezone)} 开放（预约前 10 分钟）。'
                : '本次预约的进入时间已过，可以返回预约页重新安排。',
          ),
        if (controller.isExpert && !data.videoConsent) ...[
          _notice('正在等待用户完成视频授权。'),
          const SizedBox(height: MomCozySpacing.content),
        ],
        const SizedBox(height: MomCozySpacing.card),
        if (controller.wantsToJoin &&
            data.consultation?.roomStatus == VideoRoomStatus.creating) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: MomCozySpacing.content),
          const Text('咨询室正在准备，请稍候。', textAlign: TextAlign.center),
          const SizedBox(height: MomCozySpacing.content),
        ],
        FilledButton(
          onPressed: controller.canEnter ? controller.enter : null,
          child: Text(
            controller.busy
                ? '正在进入…'
                : data.active
                ? '重新进入咨询室'
                : '进入咨询室',
          ),
        ),
        if (controller.isExpert && controller.canMarkNoShow)
          TextButton(
            onPressed: () => _end(ConsultationEndReason.userNoShow),
            child: const Text('标记用户未到场'),
          ),
      ],
    );
  }

  Future<void> _startConsultation() async {
    final data = controller.data;
    if (_flowOpen ||
        controller.busy ||
        controller.inRoom ||
        controller.pendingEnd ||
        data == null ||
        !data.windowOpen(controller.now) ||
        !data.intakeReady ||
        !data.caseConsent ||
        data.videoProvider == VideoProvider.disabled) {
      return;
    }
    setState(() => _flowOpen = true);
    try {
      final ready = await showDialog<bool>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        builder: (dialogContext) => ConsultationDeviceCheckDialog(
          createCheck: widget.createDeviceCheck,
          onSuccess: () => Navigator.pop(dialogContext, true),
        ),
      );
      if (!mounted || ready != true) return;
      await showDialog<void>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        barrierDismissible: false,
        builder: (_) => ConsultationStartDialog(
          controller: controller,
          onIntake: widget.onIntake,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _flowOpen = false);
        if (widget.overHome && !controller.inRoom && !controller.wantsToJoin) {
          widget.onBack();
        }
      }
    }
  }

  Widget _sessionHeader(ConsultationRoomContext data) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const CircleAvatar(
        radius: 18,
        backgroundColor: MomCozyColors.careSoft,
        foregroundColor: MomCozyColors.care,
        child: Icon(Icons.person_outline, size: MomCozyIconSizes.standard),
      ),
      const SizedBox(width: MomCozySpacing.statusGap),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data.appointment.providerName} · IBCLC',
              style: const TextStyle(
                fontSize: MomCozyTypography.captionSize,
                color: MomCozyColors.mutedForeground,
              ),
            ),
            const SizedBox(height: MomCozySpacing.xs),
            Text(
              '${appointmentDay(data.appointment.startsAt, data.appointment.timezone)} · ${zonedRange(data.appointment.startsAt, data.appointment.endsAt, data.appointment.timezone)}',
              style: const TextStyle(
                fontSize: MomCozyTypography.captionSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: MomCozySpacing.compact),
      MomCozyBadge(
        data.active ? '咨询中' : '等待室',
        color: MomCozyColors.care,
        background: MomCozyColors.careSoft,
      ),
    ],
  );
  Widget _expertActions(ConsultationRoomContext data) => Padding(
    padding: const EdgeInsets.only(top: MomCozySpacing.card),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!data.active)
          FilledButton(
            onPressed: controller.canStart ? controller.start : null,
            child: const Text('开始咨询'),
          ),
        if (data.active)
          FilledButton(
            onPressed: controller.busy
                ? null
                : () => _end(ConsultationEndReason.completed),
            child: const Text('完成并结束咨询'),
          ),
        TextButton(
          onPressed: controller.busy ? null : _interrupted,
          child: const Text('咨询无法继续'),
        ),
        if (controller.canMarkNoShow)
          TextButton(
            onPressed: () => _end(ConsultationEndReason.userNoShow),
            child: const Text('标记用户未到场'),
          ),
      ],
    ),
  );
  Future<void> _interrupted() async {
    final reason = await showModalBottomSheet<ConsultationEndReason>(
      context: context,
      sheetAnimationStyle: MomCozyMotion.animationStyle(context),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: MomCozyInsets.card,
                child: Text(
                  '选择结束原因',
                  style: TextStyle(
                    fontSize: MomCozyTypography.sectionSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                title: const Text('技术或网络故障'),
                subtitle: const Text('结束本次咨询，不扣减咨询次数'),
                onTap: () => Navigator.pop(
                  context,
                  ConsultationEndReason.technicalFailure,
                ),
              ),
              ListTile(
                title: const Text('需要转介或进一步医疗支持'),
                subtitle: const Text('结束本次咨询，稍后补充专业记录'),
                onTap: () => Navigator.pop(
                  context,
                  ConsultationEndReason.safetyEscalation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason != null && mounted) await _end(reason);
  }

  Future<void> _end(ConsultationEndReason reason) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: MomCozyMotion.animationStyle(context),
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('结束本次咨询？'),
        content: Text(
          reason == ConsultationEndReason.completed
              ? '完成后将扣减 1 次咨询，随后请整理咨询记录。'
              : '本次不扣减咨询次数，结束原因会保存在服务记录中。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续咨询'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.end(reason);
  }

  Widget _outcome(ConsultationRoomContext data) {
    final (title, description) = switch (data.consultation?.endReason) {
      ConsultationEndReason.technicalFailure => (
        '视频连接未能继续',
        '本次未扣减咨询次数，可以重新选择合适的时间。',
      ),
      ConsultationEndReason.userNoShow => (
        '这次咨询未能开始',
        '本次未扣减咨询次数，如需继续支持，可以重新预约。',
      ),
      ConsultationEndReason.safetyEscalation => (
        '本次咨询已结束',
        '请按专家的建议继续寻求支持，后续记录会出现在服务进度中。',
      ),
      _ =>
        data.appointment.status == AppointmentStatus.cancelled
            ? ('预约已取消', '如需继续支持，可以重新安排咨询时间。')
            : (
                '本次咨询已结束',
                controller.isExpert
                    ? '请整理本次咨询记录与后续建议。'
                    : 'IBCLC 正在整理本次建议，可在服务进度中查看。',
              ),
    };
    return MomCozySurface(
      padding: EdgeInsets.zero,
      child: ProductEmptyView(
        title: title,
        description: description,
        action: Column(
          children: [
            FilledButton(
              onPressed: () => widget.onProgress(data.appointment),
              child: Text(controller.isExpert ? '整理咨询记录' : '查看咨询总结'),
            ),
            if (!controller.isExpert &&
                data.consultation?.endReason != ConsultationEndReason.completed)
              TextButton(
                onPressed: () => widget.onRebook(data.appointment),
                child: const Text('重新预约'),
              ),
          ],
        ),
      ),
    );
  }
}
