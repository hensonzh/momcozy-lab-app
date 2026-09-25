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
        ? data.appointment.publicProviderName
        : 'Client';
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
      ConsultationMediaState.reconnecting => (
        'Reconnecting',
        'Keep this page open. We will reconnect when your network returns.',
      ),
      ConsultationMediaState.connecting => (
        'Joining consultation room',
        'Establishing video connection',
      ),
      ConsultationMediaState.disconnected => (
        'Video connection interrupted',
        'Check your network and reconnect.',
      ),
      ConsultationMediaState.connected => switch (other?.presence) {
        ParticipantPresence.reconnecting => (
          '$otherName is reconnecting',
          'The consultation is still in progress. Please stay in the room.',
        ),
        ParticipantPresence.left => (
          '$otherName has stepped away',
          'The consultation is still in progress. Please wait.',
        ),
        ParticipantPresence.joined =>
          data.active
              ? (
                  otherName,
                  remoteVideo == null
                      ? 'The other camera is off'
                      : 'In consultation',
                )
              : (
                  '$otherName has joined',
                  data.viewerRole == ConsultationRole.mom
                      ? 'Waiting for your consultant to begin'
                      : 'Both participants have joined. You can start.',
                ),
        _ => (
          'Waiting for $otherName to join',
          'You are in the room. Keep this page open.',
        ),
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
      label: 'Consultation video',
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
                    ? 'Simulated consultation · No remote audio or video'
                    : (media.state == ConsultationMediaState.connected
                          ? 'Video connected'
                          : 'Connecting video'),
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
                label: media.cameraOn
                    ? 'Your video, camera on'
                    : 'Your camera is off',
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
                          'You',
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
            label: media.microphoneOn ? 'Microphone' : 'Muted',
            icon: media.microphoneOn ? Icons.mic_none : Icons.mic_off_outlined,
            selected: media.microphoneOn,
            compact: compact,
            onTap: enabled ? media.toggleMicrophone : null,
          ),
        ),
        const SizedBox(width: MomCozySpacing.compact),
        Expanded(
          child: _Control(
            label: media.cameraOn ? 'Camera' : 'Off',
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
            label: 'Leave room',
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
