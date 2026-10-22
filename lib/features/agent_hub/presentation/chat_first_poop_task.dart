import 'package:flutter/material.dart';

import 'chat_first_demo_icon.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';

import '../domain/agent_image_input.dart';
import '../domain/chat_first_poop_task.dart';
import '../domain/stool_photo_review.dart';
import '../domain/stool_analysis.dart';

class ChatFirstPoopTaskCard extends StatelessWidget {
  const ChatFirstPoopTaskCard({
    super.key,
    required this.status,
    required this.onPick,
    required this.onSubmit,
    required this.onRemove,
    required this.onAbandon,
    required this.canInteract,
    required this.canSubmit,
    this.analysisAvailable = false,
    this.photos = const [],
    this.reviewStates = const [],
    this.sentPhotos = const [],
    this.responding = false,
    this.analysisState,
    this.onLoadPhotos,
    this.onDeleteAnalysis,
    this.deleting = false,
    this.photosLoading = false,
    this.photoFeedback,
    this.sending = false,
    this.feedback,
    this.availabilityMessage,
  });

  final ChatFirstPoopTaskStatus status;
  final List<AgentStreamImageInput> photos;
  final List<StoolPhotoReview?> reviewStates;
  final List<AgentStreamImageInput> sentPhotos;
  final bool responding;
  final StoolCardState? analysisState;
  final VoidCallback? onLoadPhotos;
  final VoidCallback? onDeleteAnalysis;
  final bool deleting;
  final bool photosLoading;
  final String? photoFeedback;
  final bool sending;
  final bool canInteract;
  final bool canSubmit;
  final bool analysisAvailable;
  final String? feedback;
  final String? availabilityMessage;
  final ValueChanged<AgentImageInputSource> onPick;
  final ValueChanged<int> onRemove;
  final VoidCallback onSubmit;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('chat-first-topic-poop'),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F3F5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E3E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: ChatFirstDemoIcon(
                    'diaper',
                    size: 17,
                    color: Color(0xFF965873),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  '看看宝宝的便便',
                  style: TextStyle(
                    color: Color(0xFF382F33),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (status == ChatFirstPoopTaskStatus.completed) ...[
                Text(
                  sentPhotos.length > 1
                      ? '已发送 ${sentPhotos.length} 张便便照片。'
                      : '已发送便便照片。',
                ),
                if (analysisState != null &&
                    sentPhotos.isEmpty &&
                    onLoadPhotos != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('chat-first-poop-load-photos'),
                    onPressed: photosLoading ? null : onLoadPhotos,
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: Text(photosLoading ? '正在加载照片…' : '查看当时照片'),
                  ),
                ],
                if (photoFeedback != null)
                  Text(
                    photoFeedback!,
                    key: const ValueKey('chat-first-poop-photo-feedback'),
                  ),
                if (sentPhotos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var index = 0; index < sentPhotos.length; index++)
                        _photoThumbnail(context, sentPhotos[index], index),
                    ],
                  ),
                ],
                if (responding) ...[
                  const SizedBox(height: 10),
                  const Text(
                    '正在整理观察…',
                    key: ValueKey('chat-first-poop-responding'),
                  ),
                ],
                if (analysisState case final analysis?) ...[
                  const SizedBox(height: 10),
                  Text(switch (analysis.status) {
                    StoolAnalysisStatus.queued => '专项结论卡已创建，正在等待已验证的分析结果…',
                    StoolAnalysisStatus.running => '专项服务正在处理照片，请稍候…',
                    StoolAnalysisStatus.failed => '专项分析未完成，请稍后重试。',
                    StoolAnalysisStatus.cancelled => '本次专项分析已取消。',
                    StoolAnalysisStatus.completed => '专项分析已完成，结论暂不可用。',
                  }, key: const ValueKey('chat-first-poop-analysis-card')),
                  if (onDeleteAnalysis != null)
                    TextButton(
                      key: const ValueKey('chat-first-poop-delete-analysis'),
                      onPressed: deleting ? null : onDeleteAnalysis,
                      child: Text(deleting ? '正在删除…' : '删除这次分析及照片'),
                    ),
                ],
              ] else if (status == ChatFirstPoopTaskStatus.cancelled)
                const Text('本次任务已取消。')
              else ...[
                if (photos.isEmpty) ...[
                  const Text(
                    '拍一张清晰的便便照片',
                    style: TextStyle(
                      color: Color(0xFF3F3539),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '选择后立即上传审核；一张即可，最多 3 张。不会自动分析。',
                    style: TextStyle(
                      color: Color(0xFF6D6264),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    '已选 ${photos.length}/3 张',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var index = 0; index < photos.length; index++)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                photos[index].localBytes!,
                                key: ValueKey(
                                  index == 0
                                      ? 'chat-first-poop-preview'
                                      : 'chat-first-poop-preview-$index',
                                ),
                                width: 78,
                                height: 78,
                                fit: BoxFit.cover,
                                semanticLabel: '待审核的便便照片 ${index + 1}',
                                errorBuilder: (context, error, stack) =>
                                    const SizedBox(
                                      width: 78,
                                      height: 78,
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                      ),
                                    ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton.filledTonal(
                                key: ValueKey('chat-first-poop-remove-$index'),
                                tooltip: '移除第 ${index + 1} 张照片',
                                onPressed: canInteract && !sending
                                    ? () => onRemove(index)
                                    : null,
                                icon: const Icon(Icons.close, size: 16),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                for (var index = 0; index < reviewStates.length; index++)
                  if (reviewStates[index] case final review?)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _reviewCopy(index, review),
                        key: ValueKey('chat-first-poop-review-$index'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF786E6B),
                        ),
                      ),
                    ),
                if (availabilityMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    availabilityMessage!,
                    key: const ValueKey('chat-first-poop-unavailable'),
                    style: const TextStyle(
                      color: Color(0xFF786E6B),
                      fontSize: 12,
                    ),
                  ),
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
                Row(
                  children: [
                    if (photos.length < 3)
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('chat-first-poop-camera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF844B62),
                            side: const BorderSide(color: Color(0xFFDCBAC9)),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: canInteract && !sending
                              ? () => onPick(AgentImageInputSource.camera)
                              : null,
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: Text(photos.isEmpty ? '拍照' : '继续拍照'),
                        ),
                      ),
                    if (photos.length < 3) const SizedBox(width: 8),
                    if (photos.length < 3)
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('chat-first-poop-photo'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF925670),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: canInteract && !sending
                              ? () => onPick(AgentImageInputSource.gallery)
                              : null,
                          icon: const Icon(Icons.photo_outlined, size: 18),
                          label: Text(photos.isEmpty ? '从相册选择' : '从相册添加'),
                        ),
                      ),
                  ],
                ),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('chat-first-poop-submit'),
                      onPressed: canInteract && canSubmit && !sending
                          ? onSubmit
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF925670),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text(sending ? '正在提交…' : '分析便便'),
                    ),
                  ),
                ],
                if (photos.isNotEmpty && !canSubmit)
                  Text(
                    reviewStates.length == photos.length &&
                            reviewStates.every(
                              (review) => review?.isApproved ?? false,
                            )
                        ? analysisAvailable
                              ? '请先进入有效对话并选择宝宝档案后再分析。'
                              : '照片审核通过；专项分析服务尚未开放。'
                        : '照片全部审核通过后才能分析；当前专项分析尚未开放。',
                  ),
                if (!sending)
                  TextButton(
                    key: const ValueKey('chat-first-poop-abandon'),
                    onPressed: onAbandon,
                    child: const Text('放弃本次任务'),
                  ),
                const Text(
                  '照片会上传至专用审核服务。审核只判断是否适合分析，不提供医学结论。',
                  style: TextStyle(color: Color(0xFF786E6B), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _photoThumbnail(
    BuildContext context,
    AgentStreamImageInput image,
    int index,
  ) {
    final bytes = image.localBytes;
    if (bytes == null) return const SizedBox.shrink();
    return IconButton(
      key: ValueKey('chat-first-poop-sent-$index'),
      tooltip: '放大查看第 ${index + 1} 张便便照片',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          key: const ValueKey('chat-first-poop-zoom'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const ValueKey('chat-first-poop-zoom-close'),
                  tooltip: '关闭照片预览',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              if (image.name.isNotEmpty)
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
      icon: Image.memory(bytes, width: 52, height: 52, fit: BoxFit.cover),
    );
  }
}

String _reviewCopy(int index, StoolPhotoReview review) {
  final reason = stoolPhotoReviewReason(review.reasonCodes);
  return '第 ${index + 1} 张：${stoolPhotoReviewLabel(review.status)}'
      '${reason == null ? '' : '（$reason）'}';
}
