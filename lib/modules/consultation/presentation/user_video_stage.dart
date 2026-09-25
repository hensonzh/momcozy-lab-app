import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../../domain/care/consultation_room.dart';
import '../../../services/consultations/consultation_media.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/design_system/mom_home_tokens.dart';

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
    final initials = data.appointment.publicProviderName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join()
        .toUpperCase();
    final status = media.sandbox
        ? 'Simulated consultation · No remote audio or video'
        : switch (media.state) {
            ConsultationMediaState.connected => 'Media connected',
            ConsultationMediaState.connecting => 'Connecting video',
            ConsultationMediaState.reconnecting => 'Reconnecting',
            ConsultationMediaState.disconnected => 'Media disconnected',
          };
    return Semantics(
      label: 'Consultation video',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MomCozyColors.mediaStageBackground,
          borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
        ),
        child: Stack(
          children: [
            if (activeVideo)
              Positioned.fill(
                child: lk.VideoTrackRenderer(
                  remoteVideo!,
                  fit: lk.VideoViewFit.cover,
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: activeVideo
                            ? MomCozyColors.mediaControlBackground
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: activeVideo
                          ? const EdgeInsets.all(8)
                          : EdgeInsets.zero,
                      child: Text(
                        status,
                        style: MomHomeTokens.text(
                          11,
                          weight: FontWeight.w700,
                          color: MomCozyColors.onMediaMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 210),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    child: Center(
                      child: activeVideo
                          ? const SizedBox.shrink()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: MomCozyColors.mediaRaised,
                                    ),
                                    child: activeFallback
                                        ? Text(
                                            initials.isEmpty ? 'IB' : initials,
                                            style: MomHomeTokens.text(
                                              24,
                                              weight: FontWeight.w700,
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
                                const SizedBox(height: 14),
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: MomHomeTokens.text(
                                    18,
                                    weight: FontWeight.w700,
                                    color: MomCozyColors.onMedia,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  detail,
                                  textAlign: TextAlign.center,
                                  style: MomHomeTokens.text(
                                    13,
                                    height: 1.55,
                                    color: MomCozyColors.onMediaMuted,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: activeVideo
                            ? Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: MomCozyColors.mediaControlBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  title,
                                  style: MomHomeTokens.text(
                                    13,
                                    weight: FontWeight.w700,
                                    color: MomCozyColors.onMedia,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Semantics(
                        label: media.cameraOn
                            ? 'Your video, camera on'
                            : 'Your camera is off',
                        child: Container(
                          width: 80,
                          height: 96,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: MomCozyColors.mediaRaised,
                            borderRadius: BorderRadius.circular(16),
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
                                    size: 24,
                                  ),
                                ),
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 8,
                                child: Text(
                                  'You',
                                  textAlign: TextAlign.center,
                                  style:
                                      MomHomeTokens.text(
                                        11,
                                        color: MomCozyColors.onMedia,
                                      ).copyWith(
                                        backgroundColor: localVideo != null
                                            ? MomCozyColors
                                                  .mediaControlBackground
                                            : null,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
