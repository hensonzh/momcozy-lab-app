import { runFocusLocalRecordSttSession } from "@/lib/chunkedStt/runFocusLocalRecordSttSession";

/**
 * 专注模式语音转写入口：使用本地录音分片上传。
 * @param params.userId 分片 STT 路径需要
 * @param params.signal 取消信号（丢弃本轮结果）
 * @param params.finishSignal 结束信号（停止录音并补一次最终转写）
 * @param params.setInterimText 实时字幕/预览
 * @returns 本轮最终识别文本（trim）
 */
export async function runFocusVoiceSttSession(params: {
  userId: string;
  signal: AbortSignal;
  finishSignal?: AbortSignal;
  setInterimText: (text: string) => void;
}): Promise<string> {
  return runFocusLocalRecordSttSession(params);
}
