import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../../services/consultations/device_check.dart';
import '../../../shared/design_system/momcozy_design_system.dart';

class ConsultationDevicePreviewDialog extends StatefulWidget {
  const ConsultationDevicePreviewDialog({super.key, this.createCheck});
  final ConsultationDeviceCheck Function()? createCheck;
  @override
  State<ConsultationDevicePreviewDialog> createState() =>
      _ConsultationDevicePreviewDialogState();
}

class _ConsultationDevicePreviewDialogState
    extends State<ConsultationDevicePreviewDialog> {
  late final check = widget.createCheck?.call() ?? ConsultationDeviceCheck();
  @override
  void dispose() {
    check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: check,
    builder: (context, _) => AlertDialog(
      scrollable: true,
      title: const Text('Camera & microphone check'),
      content: SizedBox(
        width: MomCozyLayout.maxAppWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'After tapping Start, allow camera and microphone access. This check stays on your device; audio and video are not sent to your consultant.',
              style: TextStyle(
                fontSize: MomCozyTypography.secondarySize,
                height: MomCozyTypography.lineHeight,
              ),
            ),
            const SizedBox(height: MomCozySpacing.headingGap),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MomCozyRadii.control),
                child: ColoredBox(
                  color: MomCozyColors.mediaStageBackground,
                  child: check.video == null
                      ? const Center(
                          child: Icon(
                            Icons.videocam_outlined,
                            color: MomCozyColors.onMedia,
                            size: MomCozyIconSizes.feature,
                          ),
                        )
                      : lk.VideoTrackRenderer(
                          check.video!,
                          fit: lk.VideoViewFit.cover,
                        ),
                ),
              ),
            ),
            const SizedBox(height: MomCozySpacing.content),
            Text(
              check.video != null
                  ? 'Camera is on. Make sure you can see yourself.'
                  : (check.cameraError ?? 'Camera not checked yet'),
              style: const TextStyle(fontSize: MomCozyTypography.captionSize),
            ),
            const SizedBox(height: MomCozySpacing.page),
            Row(
              children: [
                Icon(
                  check.microphoneAvailable ? Icons.mic : Icons.mic_none,
                  color: MomCozyColors.care,
                ),
                const SizedBox(width: MomCozySpacing.compact),
                Expanded(
                  child: Text(
                    check.microphoneAvailable ? 'Say something to check the input level' : 'Microphone not checked yet',
                    style: const TextStyle(
                      fontSize: MomCozyTypography.secondarySize,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MomCozySpacing.statusGap),
            LinearProgressIndicator(
              value: check.microphoneLevel,
              minHeight: 7,
              borderRadius: BorderRadius.circular(MomCozyRadii.badge),
            ),
            if (check.microphoneError != null)
              Padding(
                padding: const EdgeInsets.only(top: MomCozySpacing.compact),
                child: Text(
                  check.microphoneError!,
                  style: const TextStyle(
                    fontSize: MomCozyTypography.captionSize,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close check'),
        ),
        FilledButton(
          onPressed: check.busy ? null : check.start,
          child: Text(check.busy ? 'Checking…' : 'Start check'),
        ),
      ],
    ),
  );
}
