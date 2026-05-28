import { useCallback, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { runFocusVoiceSttSession } from "@/lib/chunkedStt/runFocusVoiceSttSession";
import { log } from "@/lib/logger";

/** 每个字符最少间隔（毫秒），控制「一字一字」观感 */
const SPEECH_CHAR_REVEAL_MS = 52;
/** 落后目标超过该字数时单帧多吐一字 */
const SPEECH_CATCH_UP_THRESHOLD = 18;

/**
 * Agent Hub 主输入麦克风：与专注模式共用 {@link runFocusVoiceSttSession}。
 *
 * @param setInput 更新输入框
 * @param options.userId 与 chat `user` 一致，供在线 STT 鉴权
 * @returns speechListening、startSpeech、stopSpeech（发送前可传 discardSttResult 丢弃转写收尾写入）
 */
export function useAgentHubSpeechInput(
  setInput: (value: string) => void,
  options: { userId: string },
): {
  speechListening: boolean;
  startSpeech: () => Promise<void>;
  stopSpeech: (opts?: { discardSttResult?: boolean }) => Promise<void>;
} {
  const [speechListening, setSpeechListening] = useState(false);
  const pipelineControlRef = useRef<{
    cancel: AbortController;
    finish: AbortController;
  } | null>(null);
  const recordingActiveRef = useRef(false);
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

  const stopPipelineStt = useCallback((mode: "finish" | "discard" = "finish") => {
    recordingActiveRef.current = false;
    const control = pipelineControlRef.current;
    if (control) {
      if (mode === "discard") {
        control.cancel.abort();
      } else {
        control.finish.abort();
      }
    }
    setSpeechListening(false);
  }, []);

  const stopSpeech = useCallback(async (opts?: { discardSttResult?: boolean }) => {
    const mode = opts?.discardSttResult ? "discard" : "finish";
    if (opts?.discardSttResult) {
      sttResultEpochRef.current += 1;
      if (speechTypewriterRafRef.current != null) {
        cancelAnimationFrame(speechTypewriterRafRef.current);
        speechTypewriterRafRef.current = null;
      }
    }
    stopPipelineStt(mode);
  }, [stopPipelineStt]);

  const startPipelineStt = useCallback(
    async (userId: string) => {
      if (typeof navigator !== "undefined" && navigator.onLine === false) {
        toast.error("当前无网络，无法使用在线语音转写");
        return;
      }

      pipelineControlRef.current?.cancel.abort();
      const sessionEpoch = ++sttResultEpochRef.current;
      const control = {
        cancel: new AbortController(),
        finish: new AbortController(),
      };
      pipelineControlRef.current = control;
      recordingActiveRef.current = true;

      resetSpeechDisplaySession("");

      setSpeechListening(true);
      try {
        const text = await runFocusVoiceSttSession({
          userId,
          signal: control.cancel.signal,
          finishSignal: control.finish.signal,
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
        if (pipelineControlRef.current === control) {
          pipelineControlRef.current = null;
          recordingActiveRef.current = false;
          setSpeechListening(false);
        }
      }
    },
    [pushSpeechTarget, resetSpeechDisplaySession, setInput],
  );

  const startSpeech = useCallback(async () => {
    if (recordingActiveRef.current) return;
    setInput("");
    const uid = options.userId.trim();
    if (!uid) {
      toast.error("缺少用户标识，无法使用语音转写");
      return;
    }
    void startPipelineStt(uid);
  }, [options.userId, startPipelineStt, setInput]);

  useEffect(() => {
    return () => {
      pipelineControlRef.current?.cancel.abort();
      pipelineControlRef.current = null;
      recordingActiveRef.current = false;
      if (speechTypewriterRafRef.current != null) {
        cancelAnimationFrame(speechTypewriterRafRef.current);
        speechTypewriterRafRef.current = null;
      }
    };
  }, []);

  return { speechListening, startSpeech, stopSpeech };
}
