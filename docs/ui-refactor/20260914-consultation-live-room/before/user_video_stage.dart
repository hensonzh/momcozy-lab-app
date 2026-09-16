import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../../domain/care/consultation_room.dart';
import '../../../services/consultations/consultation_media.dart';
import '../../../shared/design_system/momcozy_design_system.dart';

class UserConsultationVideoStage extends StatelessWidget {
  const UserConsultationVideoStage({
    super.key,
    required this.data,
    required this.media,
    required this.title,
    required this.detail,
    this.localVideo,
    this.remoteVideo,
  });
  final ConsultationRoomContext data;
  final ConsultationMedia media;
  final String title, detail;
  final lk.VideoTrack? localVideo, remoteVideo;

  @override
  Widget build(BuildContext context) {
    final activeVideo = data.active && remoteVideo != null;
    final connected = media.state == ConsultationMediaState.connected;
    final activeFallback =
        data.active &&
        connected &&
        data.participant(ConsultationRole.ibclc)?.presence ==
            ParticipantPresence.joined;
    final initials = data.appointment.providerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join()
        .toUpperCase();
    final status = media.sandbox
        ? '模拟咨询 · 无远程音视频'
        : switch (media.state) {
            ConsultationMediaState.connected => '媒体已连接',
            ConsultationMediaState.connecting => '正在连接视频',
            ConsultationMediaState.reconnecting => '正在恢复连接',
            ConsultationMediaState.disconnected => '媒体连接已断开',
          };
    return Semantics(
      label: '咨询视频画面',
      child: Container(
        constraints: const BoxConstraints(minHeight: 365),
        color: MomCozyColors.mediaStageBackground,
        child: Stack(
          children: [
            if (activeVideo)
              Positioned.fill(
                child: lk.VideoTrackRenderer(
                  remoteVideo!,
                  fit: lk.VideoViewFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 102, 24, 132),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!activeVideo) ...[
                      Container(
                        width: activeFallback ? 88 : 58,
                        height: activeFallback ? 88 : 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MomCozyColors.care.withValues(alpha: .18),
                          border: Border.all(
                            color: MomCozyColors.mediaBorder,
                            width: activeFallback ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MomCozyColors.care.withValues(alpha: .07),
                              spreadRadius: 9,
                            ),
                          ],
                        ),
                        child: Center(
                          child: activeFallback
                              ? Text(
                                  initials.isEmpty ? 'IB' : initials,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: MomCozyColors.onMedia,
                                  ),
                                )
                              : const Icon(
                                  Icons.videocam_outlined,
                                  size: 24,
                                  color: MomCozyColors.onMedia,
                                ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: MomCozyColors.onMedia,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.65,
                          color: MomCozyColors.onMediaSecondary,
                        ),
                      ),
                    ] else
                      const SizedBox(height: 131),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 13,
              left: 13,
              right: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: MomCozyColors.mediaControlBackground,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: MomCozyColors.mediaBorder),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: MomCozyColors.onMediaMuted,
                    ),
                  ),
                ),
              ),
            ),
            if (activeVideo)
              Positioned(
                left: 13,
                right: 108,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MomCozyColors.mediaControlBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MomCozyColors.onMedia,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 13,
              bottom: 13,
              child: Semantics(
                label: media.cameraOn ? '你的画面，摄像头已开启' : '你的摄像头已关闭',
                child: Container(
                  width: 82,
                  height: 108,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: MomCozyColors.mediaRaised,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: MomCozyColors.mediaBorder),
                  ),
                  child: Stack(
                    children: [
                      if (localVideo != null && media.cameraOn)
                        Positioned.fill(
                          child: lk.VideoTrackRenderer(
                            localVideo!,
                            fit: lk.VideoViewFit.cover,
                          ),
                        )
                      else
                        Center(
                          child: Icon(
                            media.cameraOn
                                ? Icons.person_outline
                                : Icons.videocam_off_outlined,
                            color: MomCozyColors.onMediaMuted,
                          ),
                        ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          '你',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: MomCozyColors.onMedia,
                            backgroundColor: localVideo != null
                                ? MomCozyColors.mediaControlBackground
                                : null,
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
