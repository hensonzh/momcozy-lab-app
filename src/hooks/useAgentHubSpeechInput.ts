import { useCallback, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { runFocusVoiceSttSession } from "@/lib/chunkedStt/runFocusVoiceSttSession";
import { log } from "@/lib/logger";

/** 每个字符最少间隔（毫秒），控制「一字一字」观感 */
const SPEECH_CHAR_REVEAL_MS = 52;
/** 落后目标超过该字数时单帧多吐一字 */
const SPEECH_CATCH_UP_THRESHOLD = 18;

/**
 * Agent Hub 主输入麦克风：与专注模式共用 {@link runFocusVoiceSttSession}（`VITE_FOCUS_STT_PROVIDER` 选讯飞或分片）。
 *
 * @param setInput 更新输入框
 * @param options.userId 与 chat `user` 一致，供在线 STT 鉴权
 * @returns speechListening、onMicClick、stopSpeech（发送前可传 discardSttResult 丢弃转写收尾写入）
 */
export function useAgentHubSpeechInput(
  setInput: (value: string) => void,
  options: { userId: string },
): {
  speechListening: boolean;
  onMicClick: () => Promise<void>;
  stopSpeech: (opts?: { discardSttResult?: boolean }) => Promise<void>;
} {
  const [speechListening, setSpeechListening] = useState(false);
  const pipelineAbortRef = useRef<AbortController | null>(null);
  /** 每次新开一轮听写递增；发送时递增以丢弃尚未完成的 setInput，避免抢在清空之后又写回输入框 */
  const sttResultEpochRef = useRef(0);

  const speechTargetRef = useRef("");
  const speechRevealedRef = useRef("");
  const speechTypewriterRafRef = useRef<number | null>(null);
  const lastRevealTsRef = useRef(0);

  const pushSpeechTarget = useCallback(
    (fullText: string) => {
      speechTargetRef.current = fullText;
      if (speechTypewriterRafRef.current != null) return;

      const tick = (now: number) => {
        const target = speechTargetRef.current;
        let revealed = speechRevealedRef.current;

        if (revealed === target) {
          speechTypewriterRafRef.current = null;
          return;
        }

        if (now - lastRevealTsRef.current < SPEECH_CHAR_REVEAL_MS) {
          speechTypewriterRafRef.current = requestAnimationFrame(tick);
          return;
        }
        lastRevealTsRef.current = now;

        if (target.startsWith(revealed)) {
          const behind = target.length - revealed.length;
          let step = 1;
          if (behind > SPEECH_CATCH_UP_THRESHOLD) step = 2;
          if (behind > SPEECH_CATCH_UP_THRESHOLD * 2) step = 3;
          revealed = target.slice(0, revealed.length + step);
        } else {
          revealed = target;
        }

        speechRevealedRef.current = revealed;
        setInput(revealed);
        speechTypewriterRafRef.current = requestAnimationFrame(tick);
      };

      speechTypewriterRafRef.current = requestAnimationFrame(tick);
    },
    [setInput],
  );

  const resetSpeechDisplaySession = useCallback(
    (prefix: string) => {
      if (speechTypewriterRafRef.current != null) {
        cancelAnimationFrame(speechTypewriterRafRef.current);
        speechTypewriterRafRef.current = null;
      }
      speechTargetRef.current = prefix;
      speechRevealedRef.current = prefix;
      lastRevealTsRef.current = 0;
      setInput(prefix);
    },
    [setInput],
  );

  const stopPipelineStt = useCallback(() => {
    if (pipelineAbortRef.current) {
      pipelineAbortRef.current.abort();
      pipelineAbortRef.current = null;
    }
    setSpeechListening(false);
  }, []);

  const stopSpeech = useCallback(async (opts?: { discardSttResult?: boolean }) => {
    if (opts?.discardSttResult) {
      sttResultEpochRef.current += 1;
      if (speechTypewriterRafRef.current != null) {
        cancelAnimationFrame(speechTypewriterRafRef.current);
        speechTypewriterRafRef.current = null;
      }
    }
    stopPipelineStt();
  }, [stopPipelineStt]);

  const startPipelineStt = useCallback(
    async (userId: string) => {
      if (typeof navigator !== "undefined" && navigator.onLine === false) {
        toast.error("当前无网络，无法使用在线语音转写");
        return;
      }

      pipelineAbortRef.current?.abort();
      const sessionEpoch = ++sttResultEpochRef.current;
      const ac = new AbortController();
      pipelineAbortRef.current = ac;

      resetSpeechDisplaySession("");

      setSpeechListening(true);
      try {
        const text = await runFocusVoiceSttSession({
          userId,
          signal: ac.signal,
          setInterimText: (interim) => {
            if (sessionEpoch !== sttResultEpochRef.current) return;
            pushSpeechTarget(interim);
          },
        });
        if (sessionEpoch !== sttResultEpochRef.current) return;
        if (speechTypewriterRafRef.current != null) {
          cancelAnimationFrame(speechTypewriterRafRef.current);
          speechTypewriterRafRef.current = null;
        }
        speechTargetRef.current = text;
        speechRevealedRef.current = text;
        setInput(text);
      } catch (e: unknown) {
        log("[AgentHub STT] 转写异常", e instanceof Error ? e.message : e);
        toast.error(e instanceof Error ? e.message : "语音转写失败");
      } finally {
        pipelineAbortRef.current = null;
        setSpeechListening(false);
      }
    },
    [pushSpeechTarget, resetSpeechDisplaySession, setInput],
  );

  const onMicClick = useCallback(async () => {
    if (speechListening) {
      await stopSpeech();
      return;
    }
    setInput("");
    const uid = options.userId.trim();
    if (!uid) {
      toast.error("缺少用户标识，无法使用语音转写");
      return;
    }
    void startPipelineStt(uid);
  }, [options.userId, speechListening, startPipelineStt, stopSpeech, setInput]);

  useEffect(() => {
    return () => {
      pipelineAbortRef.current?.abort();
      pipelineAbortRef.current = null;
      if (speechTypewriterRafRef.current != null) {
        cancelAnimationFrame(speechTypewriterRafRef.current);
        speechTypewriterRafRef.current = null;
      }
    };
  }, []);

  return { speechListening, onMicClick, stopSpeech };
}
