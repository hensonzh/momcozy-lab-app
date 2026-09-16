import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../../domain/care/consultation_room.dart';
import '../../../services/consultations/consultation_media.dart';
import '../../../services/consultations/livekit_consultation_media.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import 'user_video_stage.dart';

class ConsultationVideoStage extends StatelessWidget {
  const ConsultationVideoStage({
    super.key,
    required this.data,
    required this.media,
  });
  final ConsultationRoomContext data;
  final ConsultationMedia media;

  @override
  Widget build(BuildContext context) {
    final rtc = media is LiveKitConsultationMedia
        ? (media as LiveKitConsultationMedia).room
        : null;
    final otherRole = data.viewerRole == ConsultationRole.mom
        ? ConsultationRole.ibclc
        : ConsultationRole.mom;
    final other = data.participant(otherRole);
    final otherName = data.viewerRole == ConsultationRole.mom
        ? data.appointment.providerName
        : '用户';
    final remote = rtc?.remoteParticipants.values.firstOrNull;
    final localVideo = rtc?.localParticipant?.videoTrackPublications
        .where((publication) => !publication.muted && publication.track != null)
        .firstOrNull
        ?.track;
    final remoteVideo = remote?.videoTrackPublications
        .where((publication) => !publication.muted && publication.track != null)
        .firstOrNull
        ?.track;
    final (title, detail) = switch (media.state) {
      ConsultationMediaState.reconnecting => ('正在恢复连接', '请保持此页开启，网络恢复后会自动重连'),
      ConsultationMediaState.connecting => ('正在进入咨询室', '正在建立视频连接'),
      ConsultationMediaState.disconnected => ('视频连接已中断', '请检查网络后重新连接'),
      ConsultationMediaState.connected => switch (other?.presence) {
        ParticipantPresence.reconnecting => (
          '$otherName 正在重新连接',
          '咨询尚未结束，请留在房间中稍候',
        ),
        ParticipantPresence.left => ('$otherName 暂时离开', '咨询尚未结束，请稍候'),
        ParticipantPresence.joined =>
          data.active
              ? (otherName, remoteVideo == null ? '对方的摄像头暂未开启' : '咨询中')
              : (
                  '$otherName 已进入',
                  data.viewerRole == ConsultationRole.mom
                      ? '正在等待专家开始咨询'
                      : '双方已进入，可以开始本次咨询',
                ),
        _ => ('等待 $otherName 进入', '你已在咨询室中，可以保持此页开启'),
      },
    };
    if (data.viewerRole == ConsultationRole.mom) {
      return UserConsultationVideoStage(
        data: data,
        media: media,
        title: title,
        detail: detail,
        localVideo: localVideo,
        remoteVideo: remoteVideo,
      );
    }
    return Semantics(
      label: '咨询视频画面',
      child: Container(
        constraints: const BoxConstraints(minHeight: 365),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MomCozyColors.mediaStageBackground,
          borderRadius: BorderRadius.circular(MomCozyRadii.featured),
        ),
        child: Stack(
          children: [
            if (remoteVideo != null && data.active)
              Positioned.fill(
                child: lk.VideoTrackRenderer(
                  remoteVideo,
                  fit: lk.VideoViewFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 140),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (remoteVideo == null || !data.active) ...[
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: MomCozyColors.mediaRaised,
                        foregroundColor: MomCozyColors.onMedia,
                        child: Icon(
                          Icons.videocam_outlined,
                          size: MomCozyIconSizes.feature,
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.page),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MomCozyColors.onMedia,
                          fontSize: MomCozyTypography.sectionSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MomCozySpacing.compact),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MomCozyColors.onMediaMuted,
                          fontSize: MomCozyTypography.captionSize,
                          height: MomCozyTypography.lineHeight,
                        ),
                      ),
                    ] else
                      const SizedBox(height: 155),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Text(
                media.sandbox
                    ? '模拟咨询 · 无远程音视频'
                    : (media.state == ConsultationMediaState.connected
                          ? '视频已连接'
                          : '正在连接视频'),
                style: const TextStyle(
                  color: MomCozyColors.onMediaMuted,
                  fontSize: MomCozyTypography.microSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: Semantics(
                label: media.cameraOn ? '你的画面，摄像头已开启' : '你的摄像头已关闭',
                child: Container(
                  width: 84,
                  height: 112,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: MomCozyColors.mediaRaised,
                    borderRadius: BorderRadius.circular(MomCozyRadii.control),
                    border: Border.all(color: MomCozyColors.mediaBorder),
                  ),
                  child: Stack(
                    children: [
                      if (localVideo != null)
                        Positioned.fill(
                          child: lk.VideoTrackRenderer(
                            localVideo,
                            fit: lk.VideoViewFit.cover,
                          ),
                        )
                      else
                        const Center(
                          child: Icon(
                            Icons.videocam_off_outlined,
                            color: MomCozyColors.onMediaMuted,
                          ),
                        ),
                      const Positioned(
                        left: 10,
                        bottom: 8,
                        child: Text(
                          '你',
                          style: TextStyle(
                            color: MomCozyColors.onMedia,
                            fontSize: MomCozyTypography.labelSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConsultationMediaControls extends StatelessWidget {
  const ConsultationMediaControls({
    super.key,
    required this.media,
    required this.onLeave,
    this.compact = false,
  });
  final ConsultationMedia media;
  final VoidCallback onLeave;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final enabled =
        media.state == ConsultationMediaState.connected &&
        !media.sandbox &&
        !media.busy;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Control(
            label: media.microphoneOn ? '麦克风' : '已静音',
            icon: media.microphoneOn ? Icons.mic_none : Icons.mic_off_outlined,
            selected: media.microphoneOn,
            compact: compact,
            onTap: enabled ? media.toggleMicrophone : null,
          ),
        ),
        const SizedBox(width: MomCozySpacing.compact),
        Expanded(
          child: _Control(
            label: media.cameraOn ? '摄像头' : '已关闭',
            icon: media.cameraOn
                ? Icons.videocam_outlined
                : Icons.videocam_off_outlined,
            selected: media.cameraOn,
            compact: compact,
            camera: true,
            onTap: enabled ? media.toggleCamera : null,
          ),
        ),
        const SizedBox(width: MomCozySpacing.compact),
        Expanded(
          child: _Control(
            label: '离开房间',
            icon: Icons.logout_rounded,
            danger: true,
            compact: compact,
            onTap: onLeave,
          ),
        ),
      ],
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.icon,
    this.onTap,
    this.selected = false,
    this.danger = false,
    this.compact = false,
    this.camera = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected, danger;
  final bool compact, camera;
  @override
  Widget build(BuildContext context) => compact
      ? _momControl()
      : Semantics(
          button: true,
          enabled: onTap != null,
          selected: selected,
          child: Material(
            color: compact && danger
                ? MomCozyColors.serviceTeamSurface
                : danger
                ? MomCozyColors.roseSoft
                : MomCozyColors.muted,
            borderRadius: BorderRadius.circular(MomCozyRadii.control),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(MomCozyRadii.control),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 6 : MomCozySpacing.content,
                  horizontal: MomCozySpacing.compact,
                ),
                child: Column(
                  children: [
                    if (compact)
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: camera
                              ? MomCozyColors.blueSoft
                              : MomCozyColors.careSoft,
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: onTap == null
                              ? MomCozyColors.mutedForeground
                              : camera
                              ? MomCozyColors.blue
                              : MomCozyColors.care,
                        ),
                      )
                    else
                      Icon(
                        icon,
                        size: MomCozyIconSizes.standard,
                        color: danger
                            ? MomCozyColors.danger
                            : (onTap == null
                                  ? MomCozyColors.mutedForeground
                                  : MomCozyColors.care),
                      ),
                    SizedBox(height: compact ? 5 : MomCozySpacing.compact),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 10 : MomCozyTypography.captionSize,
                        fontWeight: FontWeight.w600,
                        color: compact && danger
                            ? MomCozyColors.serviceTeamInk
                            : danger
                            ? MomCozyColors.danger
                            : MomCozyColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

  Widget _momControl() => Semantics(
    button: true,
    enabled: onTap != null,
    selected: selected,
    child: Opacity(
      opacity: onTap == null ? .45 : 1,
      child: Material(
        color: danger
            ? MomCozyColors.roseSoft
            : camera
            ? MomCozyColors.agentLavender
            : MomHomeTokens.mint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: danger ? MomHomeTokens.rose : MomHomeTokens.teal,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: MomHomeTokens.text(12, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
