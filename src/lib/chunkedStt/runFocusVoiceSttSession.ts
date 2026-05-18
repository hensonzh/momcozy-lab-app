import { runFocusLocalRecordSttSession } from "@/lib/chunkedStt/runFocusLocalRecordSttSession";
import { runFocusIflytekRtasrSession } from "@/lib/iflytek/rtasr/runFocusIflytekRtasrSession";

/**
 * 专注模式语音转写入口：按环境变量选择讯飞 RTASR 或原有分片 WAV 上传。
 * @param params.userId 分片 STT 路径需要；讯飞路径不调用后端分片但仍要求传入以便上层统一校验
 * @param params.signal 中止信号
 * @param params.setInterimText 实时字幕/预览
 * @returns 本轮最终识别文本（trim）
 */
export async function runFocusVoiceSttSession(params: {
  userId: string;
  signal: AbortSignal;
  setInterimText: (text: string) => void;
}): Promise<string> {
  const provider = (import.meta.env.VITE_FOCUS_STT_PROVIDER as string | undefined)?.trim().toLowerCase() ?? "chunk";
  if (provider === "iflytek") {
    return runFocusIflytekRtasrSession({
      signal: params.signal,
      setInterimText: params.setInterimText,
    });
  }
  return runFocusLocalRecordSttSession(params);
}
