import { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";
import { getAgUiThreadIdForRequest } from "@/lib/agentConversationSession";
import {
  publishIbclcConsultCompleted,
  readOrCreateIbclcClientUserId,
  readStoredIbclcReturnTo,
  recordIbclcConsultCompleted,
} from "@/lib/ibclcConsult";

const CONNECTION_STEPS = [
  { text: "健康信息整理中", duration: 1000 },
  { text: "连接中", duration: 2000 },
  { text: "连接成功", duration: 1000 },
  { text: "对方正在读取背景中", duration: 2000 },
] as const;

function safeSameOriginPath(value: string | null): string {
  const raw = value?.trim();
  if (!raw) return "/";
  try {
    const url = new URL(raw, window.location.origin);
    if (url.origin !== window.location.origin) return "/";
    if (url.pathname === "/ibclc-chat.html") return "/";
    return `${url.pathname}${url.search}${url.hash}` || "/";
  } catch {
    return "/";
  }
}

function fallbackTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "Asia/Shanghai";
  } catch {
    return "Asia/Shanghai";
  }
}

function UploadImageIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5 fill-none stroke-current stroke-[2.2]">
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <circle cx="8.5" cy="10" r="1.5" />
      <path d="m21 15-4.2-4.2a2 2 0 0 0-2.8 0L6 19" />
    </svg>
  );
}

function MicIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5 fill-none stroke-current stroke-[2.2]">
      <path d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z" />
      <path d="M19 11a7 7 0 0 1-14 0" />
      <path d="M12 18v3" />
      <path d="M8 21h8" />
    </svg>
  );
}

export type IbclcChatPanelProps = {
  conversationId: string;
  consultId: string;
  clientUserId?: string;
  returnTo?: string;
  onClose?: () => void;
};

export function IbclcChatPanel({ conversationId, consultId, clientUserId = "", returnTo = "/", onClose }: IbclcChatPanelProps) {
  const navigate = useNavigate();
  const resolvedClientUserId = useMemo(
    () => clientUserId.trim() || readOrCreateIbclcClientUserId(DEFAULT_CHAT_USER_ID),
    [clientUserId],
  );
  const [connectionText, setConnectionText] = useState(CONNECTION_STEPS[0].text);
  const [isChatting, setIsChatting] = useState(false);
  const [ending, setEnding] = useState(false);

  useEffect(() => {
    let elapsed = 0;
    const timers: number[] = [];
    for (const step of CONNECTION_STEPS) {
      timers.push(window.setTimeout(() => setConnectionText(step.text), elapsed));
      elapsed += step.duration;
    }
    timers.push(window.setTimeout(() => setIsChatting(true), elapsed + 700));
    return () => timers.forEach((timer) => window.clearTimeout(timer));
  }, []);

  const returnToAgent = () => {
    if (onClose) {
      onClose();
      return;
    }
    navigate(returnTo, { replace: true });
    window.setTimeout(() => {
      if (window.location.pathname === "/ibclc-chat.html") {
        window.location.replace(returnTo);
      }
    }, 120);
  };

  const handleEndConsult = async () => {
    if (ending) return;
    setEnding(true);
    const fallback = { conversationId, consultId };
    publishIbclcConsultCompleted(
      {
        status: conversationId ? "local_completed" : "missing_conversation_id",
        conversation_id: conversationId,
        consult_id: consultId,
        event_type: "ibclc_consult_completed",
      },
      fallback,
    );
    void recordIbclcConsultCompleted({
      conversationId,
      clientUserId: resolvedClientUserId,
      consultId,
      locale: navigator.language || "zh-CN",
      timezone: fallbackTimezone(),
    }).then((result) => {
      publishIbclcConsultCompleted(result, fallback);
    });
    returnToAgent();
  };

  return (
    <div className="min-h-dvh bg-[linear-gradient(180deg,#f8fcfb_0%,#e9f2ef_100%)] text-[#172625] sm:grid sm:place-items-center sm:p-[14px]">
      <div className="mx-auto grid min-h-svh w-full max-w-[390px] grid-rows-[auto_1fr_auto] bg-white sm:h-[min(calc(100dvh_-_28px),820px)] sm:min-h-[min(calc(100dvh_-_28px),820px)] sm:overflow-hidden sm:rounded-[24px] sm:shadow-[0_18px_60px_rgba(41,74,71,0.16)]">
        <header className="border-b border-[#dce8e5] px-[14px] pb-[10px] pt-[calc(12px+env(safe-area-inset-top,0px))]">
          <div className="flex items-center justify-between gap-3">
            <h1 className="m-0 text-[18px] font-[800] leading-[1.2]">IBCLC 在线咨询</h1>
            <button
              type="button"
              disabled={ending}
              onClick={() => void handleEndConsult()}
              className="min-h-8 shrink-0 rounded-full border border-[#c84444] bg-[#d64b4b] px-3 text-[13px] font-[800] text-white disabled:opacity-75"
            >
              {ending ? "结束中..." : "结束咨询"}
            </button>
          </div>
        </header>

        <main
          className={[
            "grid min-h-0 gap-[10px] overflow-y-auto p-[14px]",
            isChatting ? "content-start" : "content-center",
          ].join(" ")}
        >
          {!isChatting ? (
            <div className="mx-auto flex w-[min(86vw,300px)] items-center justify-center gap-[10px] rounded-2xl border border-[#d9e8e4] bg-[#f7fcfa] p-[14px] shadow-[0_14px_34px_rgba(34,72,68,0.08)]">
              <div className="flex translate-y-2 animate-[messageIn_180ms_ease_forwards] items-center gap-[10px] text-[14px] font-[700] text-[#177a89] opacity-0">
                <span className="h-[9px] w-[9px] animate-pulse rounded-full bg-current" />
                <span>{connectionText}</span>
              </div>
            </div>
          ) : (
            <div className="max-w-[min(88%,310px)] translate-y-2 animate-[messageIn_260ms_ease_forwards] justify-self-start rounded-2xl bg-[#f1f7f5] px-[14px] py-3 text-[15px] leading-[1.45] text-[#233c39] opacity-0">
              你好，我是 Emily Chen，IBCLC。我已经看到你从 CoMate 带过来的背景了，你可以先告诉我现在最困扰你的哺乳问题。
            </div>
          )}
        </main>

        <footer className="grid grid-cols-[40px_minmax(0,1fr)_40px_auto] items-center gap-1.5 border-t border-[#dce8e5] bg-[#fbfefd] px-[9px] pb-[calc(9px+env(safe-area-inset-bottom,0px))] pt-[9px]">
          <button
            className="grid h-10 w-10 place-items-center rounded-full border border-[#d5e1de] bg-[#f2f8f6] p-0 text-[#28615c]"
            type="button"
            aria-label="上传图片"
          >
            <UploadImageIcon />
          </button>
          <input
            aria-label="输入消息"
            placeholder="输入消息..."
            className="min-h-10 min-w-0 rounded-full border border-[#d5e1de] px-3 py-[9px] text-[16px] outline-none"
          />
          <button
            className="grid h-10 w-10 place-items-center rounded-full border border-[#d5e1de] bg-[#f2f8f6] p-0 text-[#28615c]"
            type="button"
            aria-label="语音输入"
          >
            <MicIcon />
          </button>
          <button type="button" className="min-h-10 rounded-full bg-[#177a89] px-[14px] text-[14px] font-[800] text-white">
            发送
          </button>
        </footer>
      </div>
    </div>
  );
}

export default function IbclcChat() {
  const [searchParams] = useSearchParams();
  const conversationId = useMemo(
    () => searchParams.get("thread_id")?.trim() || getAgUiThreadIdForRequest(),
    [searchParams],
  );
  const consultId = useMemo(() => searchParams.get("consult_id")?.trim() || "", [searchParams]);
  const clientUserId = useMemo(
    () => searchParams.get("user_id")?.trim() || searchParams.get("userId")?.trim() || "",
    [searchParams],
  );
  const returnTo = useMemo(() => safeSameOriginPath(searchParams.get("return_to") || readStoredIbclcReturnTo()), [searchParams]);

  return <IbclcChatPanel conversationId={conversationId} consultId={consultId} clientUserId={clientUserId} returnTo={returnTo} />;
}
