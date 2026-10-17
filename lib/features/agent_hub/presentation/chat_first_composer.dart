import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';

import 'agent_file_previews.dart';
import 'agent_image_previews.dart';

/// The conversation-first composer has its own visual states. The legacy
/// composer remains unchanged for routes that still use the prior product UI.
class ChatFirstComposerBar extends StatelessWidget {
  const ChatFirstComposerBar({
    super.key,
    required this.menuController,
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.isRunning,
    required this.isInputLocked,
    this.voicePreviewBlocked = false,
    required this.images,
    required this.files,
    required this.loadImageThumbnail,
    required this.canAttachImage,
    required this.canAttachFile,
    required this.isAttachmentPending,
    required this.attachmentUploadProgress,
    required this.onChanged,
    required this.onSend,
    required this.onCancel,
    required this.onTakePhoto,
    required this.onPickPhoto,
    required this.onPickFile,
    required this.onRemoveImage,
    required this.onRemoveFile,
  });

  final MenuController menuController;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool canSend;
  final bool isRunning;
  final bool isInputLocked;
  final bool voicePreviewBlocked;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;
  final AgentImageContentLoader? loadImageThumbnail;
  final bool canAttachImage;
  final bool canAttachFile;
  final bool isAttachmentPending;
  final double? attachmentUploadProgress;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int> onRemoveFile;

  Widget _attachmentMenuItem({
    required Key key,
    required String label,
    required String description,
    required String iconAsset,
    required VoidCallback? onPressed,
  }) {
    return MenuItemButton(
      key: key,
      onPressed: onPressed == null
          ? null
          : () {
              menuController.close();
              onPressed();
            },
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(0, 48),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF5E7ED),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: iconAsset.endsWith('.png')
                    ? Image.asset(
                        iconAsset,
                        width: 18,
                        height: 18,
                        color: onPressed == null ? MomHomeTokens.muted : null,
                      )
                    : SvgPicture.asset(
                        iconAsset,
                        width: 18,
                        height: 18,
                        colorFilter: onPressed == null
                            ? const ColorFilter.mode(
                                MomHomeTokens.muted,
                                BlendMode.srcIn,
                              )
                            : null,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: MomHomeTokens.text(
                    14,
                    height: 18 / 14,
                    weight: FontWeight.w700,
                    color: onPressed == null
                        ? MomHomeTokens.muted
                        : MomHomeTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: MomHomeTokens.text(
                    11,
                    height: 14 / 11,
                    color: MomHomeTokens.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContent =
        controller.text.trim().isNotEmpty ||
        images.isNotEmpty ||
        files.isNotEmpty;
    final showStop = isRunning && !canSend;
    final canOpenMenu = canAttachImage || canAttachFile;
    const iconColor = Color(0xFF75696D);
    const accent = Color(0xFFA55776);

    return Padding(
      key: const ValueKey('agent-composer-bar'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (images.isNotEmpty || files.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                key: const ValueKey('agent-pending-attachments'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < images.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 94,
                          child: AgentComposerImageAttachment(
                            key: ValueKey('agent-image-attachment-$index'),
                            image: images[index],
                            loadImageThumbnail: loadImageThumbnail,
                            removeButtonKey: ValueKey(
                              index == 0
                                  ? 'agent-remove-image-button'
                                  : 'agent-remove-image-$index',
                            ),
                            onRemove: isInputLocked
                                ? null
                                : () => onRemoveImage(index),
                          ),
                        ),
                      ),
                    for (var index = 0; index < files.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 94,
                          child: AgentComposerFileAttachment(
                            key: ValueKey('agent-file-attachment-$index'),
                            file: files[index],
                            removeButtonKey: ValueKey(
                              index == 0
                                  ? 'agent-remove-file-button'
                                  : 'agent-remove-file-$index',
                            ),
                            onRemove: isInputLocked
                                ? null
                                : () => onRemoveFile(index),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (isAttachmentPending) ...[
            LinearProgressIndicator(value: attachmentUploadProgress),
            const SizedBox(height: 6),
          ],
          MenuAnchor(
            controller: menuController,
            consumeOutsideTap: true,
            alignmentOffset: const Offset(0, 8),
            style: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(Color(0xFFFFFDFC)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE9DFE4)),
                ),
              ),
            ),
            menuChildren: [
              SizedBox(
                key: const ValueKey('agent-attachment-menu'),
                width: 210,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _attachmentMenuItem(
                      key: const ValueKey('agent-attachment-camera-button'),
                      label: '相机',
                      description: '拍摄照片',
                      iconAsset: 'assets/images/cozymate_attachment_camera.png',
                      onPressed: canAttachImage ? onTakePhoto : null,
                    ),
                    _attachmentMenuItem(
                      key: const ValueKey('agent-attachment-photo-button'),
                      label: '照片',
                      description: 'JPG、PNG、WebP',
                      iconAsset: 'assets/images/cozymate_attachment_photo.svg',
                      onPressed: canAttachImage ? onPickPhoto : null,
                    ),
                    _attachmentMenuItem(
                      key: const ValueKey('agent-attachment-file-button'),
                      label: '文件',
                      description: 'PDF · 不超过 10 MB',
                      iconAsset: 'assets/images/cozymate_attachment_file.svg',
                      onPressed: canAttachFile ? onPickFile : null,
                    ),
                  ],
                ),
              ),
            ],
            child: DecoratedBox(
              key: const ValueKey('agent-composer-surface'),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEEE7E3)),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('chat-first-camera'),
                        tooltip: '拍照',
                        onPressed:
                            canAttachImage &&
                                !isAttachmentPending &&
                                !isInputLocked
                            ? () {
                                menuController.close();
                                onTakePhoto();
                              }
                            : null,
                        icon: const Icon(Icons.camera_alt_outlined, size: 21),
                        color: iconColor,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('agent-composer-input'),
                          controller: controller,
                          focusNode: focusNode,
                          onTap: menuController.close,
                          onChanged: onChanged,
                          enabled: !isInputLocked,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          scrollPadding: const EdgeInsets.only(bottom: 96),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: Color(0xFF382F33),
                          ),
                          decoration: const InputDecoration(
                            hintText: '和 Momcozy AI 聊聊…',
                            hintStyle: TextStyle(color: Color(0xFF7B7073)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (showStop)
                        IconButton(
                          key: const ValueKey('agent-stop-button'),
                          tooltip: '结束运行',
                          onPressed: onCancel,
                          icon: const Icon(Icons.stop_rounded),
                          color: accent,
                        )
                      else if (hasContent)
                        IconButton(
                          key: const ValueKey('agent-send-button'),
                          tooltip: '发送消息',
                          onPressed: canSend && !isInputLocked ? onSend : null,
                          icon: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                          ),
                          color: accent,
                        )
                      else ...[
                        IconButton(
                          key: const ValueKey('chat-first-voice-input'),
                          tooltip: '语音输入暂不可用',
                          onPressed: isInputLocked || voicePreviewBlocked
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('语音输入暂不可用，请用文字输入。'),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.mic_none_rounded, size: 21),
                          color: iconColor,
                        ),
                        IconButton(
                          key: const ValueKey('agent-attachment-button'),
                          tooltip: '添加附件',
                          onPressed: canOpenMenu && !isAttachmentPending
                              ? () {
                                  if (menuController.isOpen) {
                                    menuController.close();
                                  } else {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    menuController.open();
                                  }
                                }
                              : null,
                          icon: isAttachmentPending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_rounded, size: 24),
                          color: iconColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
