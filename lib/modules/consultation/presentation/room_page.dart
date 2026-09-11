import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../services/consultations/consultation_media.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/zoned_time.dart';
import '../../services/presentation/appointment_summary.dart';
import '../application/room_controller.dart';
import 'video_stage.dart';
import 'device_check_dialog.dart';

class ConsultationRoomPage extends StatefulWidget {
  const ConsultationRoomPage({
    super.key,
    required this.createController,
    required this.onBack,
    required this.onIntake,
    required this.onProgress,
    required this.onRebook,
  });
  final ConsultationRoomController Function() createController;
  final VoidCallback onBack;
  final Future<void> Function() onIntake;
  final void Function(CareAppointment) onProgress, onRebook;
  @override
  State<ConsultationRoomPage> createState() => _ConsultationRoomPageState();
}

class _ConsultationRoomPageState extends State<ConsultationRoomPage>
    with WidgetsBindingObserver {
  late final ConsultationRoomController controller = widget.createController();
  Timer? _timer;
  bool _allowPop = false, _leaving = false, _videoConsent = false;
  String? _region;
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
    if (_leaving) return;
    _leaving = true;
    if (controller.inRoom || controller.wantsToJoin) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
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
        _leaving = false;
        return;
      }
    }
    await controller.leave();
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) widget.onBack();
    _leaving = false;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope(
      canPop: _allowPop || (!controller.inRoom && !controller.wantsToJoin),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: const Text('视频咨询'),
          actions: [
            IconButton(
              tooltip: '刷新咨询状态',
              onPressed: controller.busy ? null : controller.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: MomCozyPageBody(
          maxWidth: controller.isExpert ? 760 : MomCozyLayout.maxAppWidth,
          child: _body(),
        ),
      ),
    ),
  );
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
    return ListView(
      padding: MomCozyInsets.page,
      children: [
        if (controller.message case final message?) _notice(message),
        if (controller.pendingEnd)
          FilledButton(
            onPressed: controller.busy ? null : controller.retryEnd,
            child: const Text('核对结束咨询的结果'),
          ),
        if (data.ended)
          _outcome(data)
        else if (!controller.inRoom)
          _preparation(data)
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
  Widget _preparation(ConsultationRoomContext data) {
    final locationReady = data.location?.validAt(controller.now) ?? false;
    final region = _region ?? data.appointment.region;
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
                  builder: (context) => const ConsultationDeviceCheckDialog(),
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
        if (!controller.isExpert &&
            (!data.intakeReady || !data.caseConsent)) ...[
          MomCozySurface(
            padding: MomCozyInsets.compactCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.assignment_outlined,
                  color: MomCozyColors.care,
                ),
                const SizedBox(height: MomCozySpacing.compact),
                Text(
                  data.intakeReady ? '查看资料共享授权' : '完成信息采集',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Text(
                  '让本次负责的 IBCLC 了解你的喂养情况。',
                  style: TextStyle(
                    fontSize: MomCozyTypography.captionSize,
                    height: MomCozyTypography.lineHeight,
                  ),
                ),
                TextButton(
                  onPressed: controller.busy
                      ? null
                      : () async {
                          await widget.onIntake();
                          await controller.load();
                        },
                  child: const Text('查看信息采集表'),
                ),
              ],
            ),
          ),
          const SizedBox(height: MomCozySpacing.content),
        ],
        if (!data.videoConsent) ...[
          if (controller.isExpert)
            _notice('正在等待用户完成视频授权。')
          else
            MomCozySurface(
              padding: MomCozyInsets.compactCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '视频咨询授权',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: MomCozySpacing.compact),
                  const Text(
                    '开启后，可以与本次负责的 IBCLC 进行实时音视频咨询。',
                    style: TextStyle(
                      fontSize: MomCozyTypography.captionSize,
                      height: MomCozyTypography.lineHeight,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('room-video-consent'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _videoConsent,
                    onChanged: controller.busy
                        ? null
                        : (value) =>
                              setState(() => _videoConsent = value ?? false),
                    title: const Text(
                      '我同意开启本次服务的视频咨询',
                      style: TextStyle(
                        fontSize: MomCozyTypography.secondarySize,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _videoConsent && !controller.busy
                        ? controller.grantVideoConsent
                        : null,
                    child: const Text('确认视频授权'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: MomCozySpacing.content),
        ],
        if (!controller.isExpert)
          MomCozySurface(
            padding: MomCozyInsets.compactCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      locationReady
                          ? Icons.check_circle_outline
                          : Icons.location_on_outlined,
                      color: MomCozyColors.care,
                      size: MomCozyIconSizes.medium,
                    ),
                    const SizedBox(width: MomCozySpacing.compact),
                    Expanded(
                      child: Text(
                        locationReady
                            ? '当前位置已确认 · ${data.location!.region}'
                            : '确认当前所在州',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (!locationReady) ...[
                  const SizedBox(height: MomCozySpacing.content),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('room-location'),
                    initialValue: region,
                    decoration: const InputDecoration(labelText: '当前所在州'),
                    isExpanded: true,
                    itemHeight: null,
                    items: [
                      const DropdownMenuItem(
                        value: 'CA',
                        child: Text('California (CA)'),
                      ),
                      const DropdownMenuItem(
                        value: 'NY',
                        child: Text('New York (NY)'),
                      ),
                      const DropdownMenuItem(
                        value: 'TX',
                        child: Text('Texas (TX)'),
                      ),
                      if (!['CA', 'NY', 'TX'].contains(region))
                        DropdownMenuItem(value: region, child: Text(region)),
                    ],
                    onChanged: controller.busy
                        ? null
                        : (value) => setState(() => _region = value),
                  ),
                  const SizedBox(height: MomCozySpacing.content),
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.checkLocation(region),
                    child: const Text('确认当前位置'),
                  ),
                ],
              ],
            ),
          ),
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
            controller.busy ? '正在进入…' : (data.active ? '重新进入咨询室' : '进入咨询室'),
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
