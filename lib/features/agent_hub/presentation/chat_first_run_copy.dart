import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';

const chatFirstNoResponse = '这次没有收到回复。';
const chatFirstRetry = '重试';
const chatFirstRestoringHistory = '正在恢复对话…';
const chatFirstHistoryLoadFailed = '历史消息暂时无法加载，点击重试。';
const chatFirstHistorySyncFailed = '历史消息暂时无法同步，点击重试。';
const chatFirstOlderHistoryFailed = '更早消息加载失败，点击重试。';
const chatFirstLoadOlderHistory = '加载更早消息';
const chatFirstImageUploadFailed = '图片上传失败，请重试。';
const chatFirstDocumentUploadFailed = '文件上传失败，请重试。';
const chatFirstDocumentTooLarge = '文件不能超过 10 MB。';
const chatFirstDocumentUnsupported = '目前仅支持 PDF 文件。';
const chatFirstConversationOpenFailed = '无法打开此对话。';

String chatFirstWorkStatus(String? source) {
  final label = source?.trim() ?? '';
  if (label.isEmpty) return '正在思考…';
  // The Agent may supply localized status text. Do not surface a fixed English
  // transport label in the Chinese product; keep its underlying state intact.
  return RegExp(r'[\u3400-\u9fff]').hasMatch(label) ? label : '正在处理…';
}

String? chatFirstSupportingText(AgentStreamRunState state) =>
    switch (state.phase) {
      AgentStreamRunPhase.waitingForConfirmation => '当前版本不支持此操作，可继续提问。',
      AgentStreamRunPhase.disconnected => '连接中断，请检查网络后尝试继续接收。',
      AgentStreamRunPhase.error => '请求未完成，请检查网络后重试。',
      AgentStreamRunPhase.cancelRequested => '正在请求结束运行…',
      AgentStreamRunPhase.cancelled =>
        state.cancelAcknowledged ? '回复已停止。' : '已在本机停止；服务器端结束尚未确认。',
      _ => null,
    };

String chatFirstFallbackText(
  AgentStreamRunState state, {
  required String greeting,
}) => switch (state.phase) {
  AgentStreamRunPhase.idle => greeting,
  AgentStreamRunPhase.streaming => '',
  AgentStreamRunPhase.cancelRequested => '正在结束本次回复…',
  AgentStreamRunPhase.cancelled =>
    state.cancelAcknowledged ? '回复已停止。' : '已在本机停止；服务器端结束尚未确认。',
  AgentStreamRunPhase.waitingForConfirmation => '当前版本不支持此操作。',
  AgentStreamRunPhase.finished => '请求已结束，但没有可显示的回复。',
  AgentStreamRunPhase.error ||
  AgentStreamRunPhase.disconnected => chatFirstNoResponse,
};
