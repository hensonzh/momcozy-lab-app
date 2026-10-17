import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/agent_image_input.dart';
import '../domain/chat_first_poop_task.dart';

class ChatFirstPoopTaskCard extends StatelessWidget {
  const ChatFirstPoopTaskCard({
    super.key,
    required this.status,
    required this.onPick,
    required this.onSubmit,
    required this.onAbandon,
    required this.canInteract,
    required this.canSubmit,
    this.photoBytes,
    this.photoName,
    this.sending = false,
    this.feedback,
  });

  final ChatFirstPoopTaskStatus status;
  final Uint8List? photoBytes;
  final String? photoName;
  final bool sending;
  final bool canInteract;
  final bool canSubmit;
  final String? feedback;
  final ValueChanged<AgentImageInputSource> onPick;
  final VoidCallback onSubmit;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('chat-first-topic-poop'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFDFC),
      border: Border.all(color: const Color(0xFFEEE5E1)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.child_care_outlined, color: Color(0xFFA55776)),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                '看看宝宝的便便',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (status == ChatFirstPoopTaskStatus.completed)
          const Text('已发送便便照片。')
        else if (status == ChatFirstPoopTaskStatus.cancelled)
          const Text('本次任务已取消。')
        else ...[
          if (photoBytes == null) ...[
            const Text(
              '拍一张清晰的便便照片',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('尽量在自然光下拍摄，让颜色和形态看得更清楚。'),
          ] else ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                photoBytes!,
                key: const ValueKey('chat-first-poop-preview'),
                height: 150,
                width: double.infinity,
                fit: BoxFit.contain,
                semanticLabel: '待发送的便便照片',
              ),
            ),
            if (photoName != null)
              Text(photoName!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          if (feedback != null) ...[
            const SizedBox(height: 8),
            Text(
              feedback!,
              key: const ValueKey('chat-first-poop-feedback'),
              style: const TextStyle(color: Color(0xFFAA385A)),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('chat-first-poop-camera'),
                onPressed: canInteract && !sending
                    ? () => onPick(AgentImageInputSource.camera)
                    : null,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(photoBytes == null ? '拍照' : '重新拍摄'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('chat-first-poop-photo'),
                onPressed: canInteract && !sending
                    ? () => onPick(AgentImageInputSource.gallery)
                    : null,
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: Text(photoBytes == null ? '从相册选择' : '更换照片'),
              ),
              if (photoBytes != null)
                FilledButton(
                  key: const ValueKey('chat-first-poop-submit'),
                  onPressed: canInteract && canSubmit && !sending
                      ? onSubmit
                      : null,
                  child: Text(sending ? '正在发送…' : '发送并查看'),
                ),
            ],
          ),
          if (photoBytes != null && !canSubmit) const Text('照片发送暂不可用，照片尚未上传。'),
          if (!sending)
            TextButton(
              key: const ValueKey('chat-first-poop-abandon'),
              onPressed: onAbandon,
              child: const Text('放弃本次任务'),
            ),
          const Text(
            '仅整理照片中可见的观察线索，不作为诊断。确认发送前照片仅保留在本机。',
            style: TextStyle(color: Color(0xFF786E6B), fontSize: 12),
          ),
        ],
      ],
    ),
  );
}
