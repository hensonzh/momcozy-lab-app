import { toast } from "sonner";
import { startFocusModePcmCapture } from "@/lib/chunkedStt/focusModeMicPcm";
import { log } from "@/lib/logger";
import { buildIflytekRtasrWsUrl } from "@/lib/iflytek/rtasr/buildIflytekRtasrSigna";
import {
  applyIflytekRtasrSegmentUpdate,
  mergeIflytekRtasrSlots,
  parseIflytekRtasrDataPayload,
  type IflytekRtasrSegSlot,
} from "@/lib/iflytek/rtasr/parseIflytekRtasrData";

/** 文档建议：每 40ms 发送 1280 字节的 16kHz/16bit/mono PCM */
const RTASR_FRAME_BYTES = 1280;
const RTASR_FRAME_MS = 40;
/** 单轮最长录音时间 */
const MAX_SESSION_MS = 60_000;
/** 检测到说话后，持续静音多久视为说完（发送 end 收尾） */
const SILENCE_END_MS = 1800;
/** 判定「有声」的 RMS 阈值（约 0～1，按 int16 归一化后能量） */
const RMS_SPEECH_THRESHOLD = 0.02;
/** 握手后若迟迟无 started 则失败 */
const HANDSHAKE_TIMEOUT_MS = 12_000;
/** 发送 end 后等待连接关闭以收取尾包 */
const AFTER_END_WAIT_MS = 8000;

/**
 * 计算 s16le 块的 RMS（用于简易静音检测，触发自动收尾）。
 * @param i16 单声道 PCM
 * @returns 约 0～1 的能量指标
 */
function pcmChunkRms(i16: Int16Array): number {
  if (i16.length === 0) return 0;
  let sum = 0;
  for (let i = 0; i < i16.length; i++) {
    const v = i16[i]! / 32768;
    sum += v * v;
  }
  return Math.sqrt(sum / i16.length);
}

/**
 * 专注模式：讯飞实时语音转写（RTASR）WebSocket；16k PCM 按文档节奏发送，静音或超时自动 end，亦可 AbortSignal 打断。
 * 注意：apiKey 经 Vite 注入会打进前端包，正式环境建议改为服务端代签 + 代理（防密钥泄露）。
 *
 * @param params.signal 外部取消：尽快发送 end 并以当前文稿结束
 * @param params.setInterimText 实时展示合并后的识别全文
 * @returns 最终用户话术（trim），失败或无声时可能为空字符串
 */
export async function runFocusIflytekRtasrSession(params: {
  signal: AbortSignal;
  setInterimText: (text: string) => void;
}): Promise<string> {
  if (typeof navigator !== "undefined" && navigator.onLine === false) {
    toast.error("当前无网络，无法使用在线语音转写");
    return "";
  }

  const appid = (import.meta.env.VITE_IFLYTEK_RTASR_APPID as string | undefined)?.trim() ?? "";
  const apiKey = (import.meta.env.VITE_IFLYTEK_RTASR_API_KEY as string | undefined)?.trim() ?? "";
  if (!appid || !apiKey) {
    toast.error("未配置讯飞实时转写：请设置 VITE_IFLYTEK_RTASR_APPID 与 VITE_IFLYTEK_RTASR_API_KEY");
    return "";
  }

  const extra: Record<string, string> = {};
  const lang = (import.meta.env.VITE_IFLYTEK_RTASR_LANG as string | undefined)?.trim();
  if (lang) extra.lang = lang;
  const pd = (import.meta.env.VITE_IFLYTEK_RTASR_PD as string | undefined)?.trim();
  if (pd) extra.pd = pd;
  const engLangType = (import.meta.env.VITE_IFLYTEK_RTASR_ENG_LANG_TYPE as string | undefined)?.trim();
  if (engLangType) extra.engLangType = engLangType;

  let settled = false;
  let byteQueue = new Uint8Array(0);
  /** 按文档按 seg_id 分槽：type=1 只更新 draft，type=0 写入 final 并锁定该段 */
  const segmentSlots = new Map<number, IflytekRtasrSegSlot>();
  let ws: WebSocket | null = null;
  let sendTimer: ReturnType<typeof setInterval> | null = null;
  let handshakeTimer: ReturnType<typeof setTimeout> | null = null;
  let maxTimer: ReturnType<typeof setTimeout> | null = null;
  let silenceCheckTimer: ReturnType<typeof setInterval> | null = null;
  let flushTimer: ReturnType<typeof setInterval> | null = null;
  let afterEndTimer: ReturnType<typeof setTimeout> | null = null;
  let mic: { close: () => Promise<void> } | null = null;
  let handshakeOk = false;
  let hadSpeechEnergy = false;
  let lastSpeechAt = 0;
  let ending = false;
  let endSent = false;

  const pushPcmS16le = (i16: Int16Array) => {
    const u8 = new Uint8Array(i16.buffer, i16.byteOffset, i16.byteLength);
    const next = new Uint8Array(byteQueue.length + u8.length);
    if (byteQueue.length) next.set(byteQueue);
    next.set(u8, byteQueue.length);
    byteQueue = next;
  };

  const takeFrame = (): Uint8Array | null => {
    if (byteQueue.length < RTASR_FRAME_BYTES) return null;
    const out = byteQueue.slice(0, RTASR_FRAME_BYTES);
    byteQueue = byteQueue.slice(RTASR_FRAME_BYTES);
    return out;
  };

  const refreshDisplay = () => {
    params.setInterimText(mergeIflytekRtasrSlots(segmentSlots));
  };

  const clearSendTimer = () => {
    if (sendTimer != null) {
      clearInterval(sendTimer);
      sendTimer = null;
    }
  };

  const clearSilenceTimer = () => {
    if (silenceCheckTimer != null) {
      clearInterval(silenceCheckTimer);
      silenceCheckTimer = null;
    }
  };

  const clearFlushTimer = () => {
    if (flushTimer != null) {
      clearInterval(flushTimer);
      flushTimer = null;
    }
  };

  const clearAllTimers = () => {
    if (handshakeTimer != null) {
      clearTimeout(handshakeTimer);
      handshakeTimer = null;
    }
    if (maxTimer != null) {
      clearTimeout(maxTimer);
      maxTimer = null;
    }
    if (afterEndTimer != null) {
      clearTimeout(afterEndTimer);
      afterEndTimer = null;
    }
    clearSendTimer();
    clearSilenceTimer();
    clearFlushTimer();
  };

  const applyResultData = (dataStr: string) => {
    const parsed = parseIflytekRtasrDataPayload(dataStr);
    if (!parsed) return;
    applyIflytekRtasrSegmentUpdate(segmentSlots, parsed.segId, parsed.isFinal, parsed.text);
    refreshDisplay();
  };

  return new Promise<string>((resolve) => {
    const finish = async (out: string) => {
      if (settled) return;
      settled = true;
      params.signal.removeEventListener("abort", onAbort);
      clearAllTimers();
      try {
        await mic?.close();
      } catch {
        /* noop */
      }
      mic = null;
      try {
        ws?.close();
      } catch {
        /* noop */
      }
      ws = null;
      resolve(out.trim());
    };

    const onAbort = () => {
      void teardownAndEnd("abort");
    };

    const teardownAndEnd = async (reason: "abort" | "silence" | "max" | "error") => {
      if (ending || settled) return;
      ending = true;
      clearSendTimer();
      clearSilenceTimer();
      clearFlushTimer();
      if (maxTimer != null) {
        clearTimeout(maxTimer);
        maxTimer = null;
      }

      try {
        await mic?.close();
      } catch {
        /* noop */
      }
      mic = null;

      if (!ws) {
        void finish(mergeIflytekRtasrSlots(segmentSlots));
        return;
      }
      if (ws.readyState === WebSocket.CONNECTING) {
        try {
          ws.close();
        } catch {
          /* noop */
        }
        void finish(mergeIflytekRtasrSlots(segmentSlots));
        return;
      }
      if (ws.readyState !== WebSocket.OPEN) {
        void finish(mergeIflytekRtasrSlots(segmentSlots));
        return;
      }
      if (!handshakeOk) {
        try {
          ws.close();
        } catch {
          /* noop */
        }
        void finish(mergeIflytekRtasrSlots(segmentSlots));
        return;
      }

      // 未正常握手时 error 路径：直接关闭（无需 end）
      if (reason === "error") {
        try {
          ws.close();
        } catch {
          /* noop */
        }
        void finish(mergeIflytekRtasrSlots(segmentSlots));
        return;
      }

      // 按 40ms 节奏 flush 剩余 PCM，再发送文档要求的 end 二进制帧
      flushTimer = setInterval(() => {
        if (!ws || ws.readyState !== WebSocket.OPEN) {
          clearFlushTimer();
          return;
        }
        if (byteQueue.length >= RTASR_FRAME_BYTES) {
          const frame = byteQueue.slice(0, RTASR_FRAME_BYTES);
          byteQueue = byteQueue.slice(RTASR_FRAME_BYTES);
          ws.send(frame);
          return;
        }
        clearFlushTimer();
        if (byteQueue.length > 0) {
          ws.send(byteQueue);
          byteQueue = new Uint8Array(0);
        }
        if (!endSent) {
          endSent = true;
          try {
            ws.send(new TextEncoder().encode('{"end": true}'));
          } catch (e: unknown) {
            log("[Focus RTASR] 发送 end 失败", e instanceof Error ? e.message : e);
          }
        }
        // 通常服务端在收齐尾包后会断开；此处仅作兜底，避免永久挂起
        afterEndTimer = setTimeout(() => {
          afterEndTimer = null;
          if (!settled) void finish(mergeIflytekRtasrSlots(segmentSlots));
        }, AFTER_END_WAIT_MS);
      }, RTASR_FRAME_MS);
    };

    params.signal.addEventListener("abort", onAbort, { once: true });

    void (async () => {
      let url: string;
      try {
        url = await buildIflytekRtasrWsUrl(appid, apiKey, extra);
      } catch (e: unknown) {
        log("[Focus RTASR] 构建握手 URL 失败", e instanceof Error ? e.message : e);
        toast.error("讯飞转写鉴权失败");
        void finish("");
        return;
      }

      ws = new WebSocket(url);

      handshakeTimer = setTimeout(() => {
        handshakeTimer = null;
        if (handshakeOk || settled) return;
        toast.error("讯飞实时转写握手超时，请检查网络与密钥");
        void finish(mergeIflytekRtasrSlots(segmentSlots));
      }, HANDSHAKE_TIMEOUT_MS);

      maxTimer = setTimeout(() => {
        maxTimer = null;
        void teardownAndEnd("max");
      }, MAX_SESSION_MS);

      ws.onmessage = (ev: MessageEvent<string>) => {
        if (settled) return;
        try {
          const msg = JSON.parse(ev.data) as {
            action?: string;
            code?: string;
            data?: string;
            desc?: string;
          };
          const action = msg.action;
          if (action === "started" && msg.code === "0") {
            handshakeOk = true;
            if (handshakeTimer != null) {
              clearTimeout(handshakeTimer);
              handshakeTimer = null;
            }
            if (!sendTimer && !ending) {
              sendTimer = setInterval(() => {
                if (!ws || ws.readyState !== WebSocket.OPEN || ending) return;
                const frame = takeFrame();
                if (frame) ws.send(frame);
              }, RTASR_FRAME_MS);
            }
            return;
          }
          if (action === "result" && msg.code === "0" && typeof msg.data === "string") {
            applyResultData(msg.data);
            return;
          }
          if (action === "error") {
            const desc = msg.desc ?? "讯飞转写错误";
            log("[Focus RTASR] 服务端错误", desc, msg.code);
            toast.error(desc);
            void teardownAndEnd("error");
          }
        } catch (e: unknown) {
          log("[Focus RTASR] 解析消息失败", e instanceof Error ? e.message : e);
        }
      };

      ws.onerror = () => {
        if (settled) return;
        toast.error("讯飞实时转写连接异常");
        void teardownAndEnd("error");
      };

      ws.onclose = () => {
        if (settled) return;
        const text = mergeIflytekRtasrSlots(segmentSlots);
        void finish(text);
      };

      try {
        mic = await startFocusModePcmCapture({
          signal: params.signal,
          isActive: () => !settled && !ending,
          onPcmS16le: (chunk) => {
            if (ending || settled) return;
            const rms = pcmChunkRms(chunk);
            if (rms >= RMS_SPEECH_THRESHOLD) {
              hadSpeechEnergy = true;
              lastSpeechAt = Date.now();
            }
            pushPcmS16le(chunk);
          },
        });
      } catch {
        void finish("");
        return;
      }

      if (params.signal.aborted) {
        void finish("");
        return;
      }

      // 周期性检测静音收尾（需先有过有效语音能量，避免一开麦就 end）
      silenceCheckTimer = setInterval(() => {
        if (settled || ending || !hadSpeechEnergy) return;
        if (Date.now() - lastSpeechAt >= SILENCE_END_MS) {
          void teardownAndEnd("silence");
        }
      }, 300);
    })();
  });
}
