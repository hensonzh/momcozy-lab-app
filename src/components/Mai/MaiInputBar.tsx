import React, { useEffect, useRef, useState } from "react";
import { Send, Mic, Keyboard, Camera, Upload, ImagePlus, X, Square } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { arMockResults } from "@/data/deviceMockData";
import type { PhotoIdentifyResult } from "@/data/deviceMockData";
import type { AgentHubSpeechPhase } from "@/hooks/useAgentHubSpeechInput";
import mockDuckbillImg from "@/assets/mock-duckbill.jpg";
import mockFlangeImg from "@/assets/mock-flange.jpg";
import mockSealImg from "@/assets/mock-seal.jpg";

const mockImageMap: Record<string, string> = {
  duckbill: mockDuckbillImg,
  flange: mockFlangeImg,
  seal: mockSealImg,
};

const voiceWaveBars = [8, 10, 7, 13, 18, 12, 22, 16, 25, 14, 19, 11, 16, 9, 12, 7];

interface MaiInputBarProps {
  value: string;
  onChange: (val: string) => void;
  onSend: () => void;
  onVoiceStart?: () => void | Promise<void>;
  onVoiceEnd?: (opts?: { submit?: boolean }) => void | Promise<void>;
  onPhotoFile?: (file: File) => void;
  onDemoIdentify?: (result: PhotoIdentifyResult) => void;
  /** 正在语音听写：高亮麦克风并让输入框只读，避免与流式转写互相覆盖 */
  speechListening?: boolean;
  speechPhase?: AgentHubSpeechPhase;
  /** Hub 等设备：发送后对话流进行中时为 true；空输入点击停止，有内容则发送新一轮。 */
  sendLoading?: boolean;
  /** 已有图片等附件可随本轮消息发送，即使输入框为空也允许发送 */
  canSendWithoutText?: boolean;
  disabled?: boolean;
  placeholder?: string;
  showPhotoMenu?: boolean;
  onTogglePhotoMenu?: (open: boolean) => void;
  /** Extra class on outer wrapper */
  className?: string;
  /** Bottom padding style — "main" (pb-20), "drawer" (pb-6), or "fixed" (pb-0) */
  variant?: "main" | "drawer" | "fixed";
}

const MaiInputBar: React.FC<MaiInputBarProps> = ({
  value,
  onChange,
  onSend,
  onVoiceStart,
  onVoiceEnd,
  onPhotoFile,
  onDemoIdentify,
  speechListening = false,
  speechPhase = speechListening ? "listening" : "idle",
  sendLoading = false,
  canSendWithoutText = false,
  disabled = false,
  placeholder = "和 Comate 聊聊...",
  showPhotoMenu = false,
  onTogglePhotoMenu,
  className,
  variant = "main",
}) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);
  const composingRef = useRef(false);
  const compositionEndAtRef = useRef(0);
  const voicePressActiveRef = useRef(false);
  const textDraftBeforeVoiceRef = useRef<string | null>(null);
  const [voiceMode, setVoiceMode] = useState(false);
  const hasSendableContent = value.trim().length > 0 || canSendWithoutText;
  const sendIsStop = sendLoading && !hasSendableContent;
  /** 有文字、附件或生成中（打断）时用主色按钮；仅完全空且非加载时置灰样式 */
  const sendLooksActive = hasSendableContent || sendLoading;
  const voiceTranscribing = speechPhase === "transcribing";
  const voiceDisabled = disabled || !onVoiceStart || !onVoiceEnd || voiceTranscribing;
  const voiceOverlayVisible = voiceMode && speechListening;
  const voiceOverlayText = value.trim();
  const previousSpeechPhaseRef = useRef<AgentHubSpeechPhase>(speechPhase);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file && onPhotoFile) onPhotoFile(file);
    e.target.value = "";
  };

  const handlePaste = (e: React.ClipboardEvent<HTMLInputElement>) => {
    if (!onPhotoFile || speechListening || disabled) return;

    const itemFiles = Array.from(e.clipboardData.items ?? [])
      .filter((item) => item.kind === "file" && item.type.startsWith("image/"))
      .map((item) => item.getAsFile())
      .filter((file): file is File => Boolean(file));
    const files = itemFiles.length > 0
      ? itemFiles
      : Array.from(e.clipboardData.files ?? []).filter((file) => file.type.startsWith("image/"));

    if (files.length === 0) return;
    e.preventDefault();
    onTogglePhotoMenu?.(false);
    files.forEach((file) => onPhotoFile(file));
  };

  const voiceHoldLabel = voiceTranscribing
    ? value.trim() || "正在整理语音..."
    : speechListening
      ? value.trim() || "我在听，松开后文字填入输入框"
      : "按住说话";
  const VoiceToggleIcon = voiceMode ? Keyboard : Mic;

  const toggleVoiceMode = () => {
    if (voiceDisabled || speechListening) return;
    onTogglePhotoMenu?.(false);
    if (voiceMode) {
      if (!value.trim() && textDraftBeforeVoiceRef.current) {
        onChange(textDraftBeforeVoiceRef.current);
      }
      textDraftBeforeVoiceRef.current = null;
      setVoiceMode(false);
      return;
    }
    textDraftBeforeVoiceRef.current = value;
    if (value) onChange("");
    setVoiceMode(true);
  };

  const startVoiceHold = () => {
    if (voiceDisabled || voicePressActiveRef.current) return;
    textDraftBeforeVoiceRef.current = null;
    voicePressActiveRef.current = true;
    void onVoiceStart?.();
  };

  const finishVoiceHold = (opts?: { submit?: boolean }) => {
    if (!voicePressActiveRef.current) return;
    voicePressActiveRef.current = false;
    textDraftBeforeVoiceRef.current = null;
    setVoiceMode(false);
    void onVoiceEnd?.(opts);
  };

  useEffect(() => {
    const previous = previousSpeechPhaseRef.current;
    previousSpeechPhaseRef.current = speechPhase;
    if (previous === "idle" || speechPhase !== "idle") return;
    voicePressActiveRef.current = false;
    textDraftBeforeVoiceRef.current = null;
    setVoiceMode(false);
  }, [speechPhase]);

  return (
    <div className={cn("flex-shrink-0", className)}>
      <AnimatePresence>
        {voiceOverlayVisible && (
          <motion.div
            className="pointer-events-none fixed inset-x-0 bottom-[118px] z-[80] flex justify-center px-6"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            aria-hidden
          >
            <style>{`
              @keyframes voice-wave {
                from { transform: scaleY(0.68); opacity: 0.55; }
                to { transform: scaleY(1.18); opacity: 1; }
              }
            `}</style>
            <motion.div
              className="relative flex min-h-[82px] w-full max-w-[310px] items-center justify-center rounded-[26px] border border-[#ead6df] bg-[#f8eef3] px-6 py-4 text-center text-[15px] font-[700] leading-relaxed text-[#563544] shadow-[0_12px_28px_rgba(117,76,94,0.16)]"
              initial={{ scale: 0.94, y: 10 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.96, y: 8 }}
              transition={{ type: "spring", stiffness: 380, damping: 30 }}
            >
              <div className="absolute -bottom-3 left-1/2 h-6 w-6 -translate-x-1/2 rotate-45 border-b border-r border-[#ead6df] bg-[#f8eef3]" />
              {voiceOverlayText ? (
                <span className="relative z-10 max-h-[4.2rem] overflow-hidden break-words">{voiceOverlayText}</span>
              ) : (
                <div className="relative z-10 flex h-8 items-center gap-[3px]" aria-label="正在听">
                  {voiceWaveBars.map((height, index) => (
                    <span
                      key={`${height}-${index}`}
                      className="block w-[3px] rounded-full bg-[#9a6d7f] opacity-80"
                      style={{
                        height,
                        animation: `voice-wave 900ms ease-in-out ${index * 45}ms infinite alternate`,
                      }}
                    />
                  ))}
                </div>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Photo menu popup */}
      <AnimatePresence>
        {showPhotoMenu && (
          <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 12 }}
            className="mx-0 mb-2 rounded-2xl bg-card border border-border shadow-lg p-3 space-y-2.5">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold text-foreground flex items-center gap-1.5">
                <Camera className="w-3.5 h-3.5 text-primary" /> 选择识别方式
              </span>
              <button onClick={() => onTogglePhotoMenu?.(false)} className="text-muted-foreground hover:text-foreground">
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
            <div className="flex gap-2">
              <Button size="sm" onClick={() => cameraInputRef.current?.click()} className="flex-1 rounded-xl h-9 gap-1.5 text-xs">
                <Camera className="w-3.5 h-3.5" /> 拍照
              </Button>
              <Button size="sm" variant="outline" onClick={() => fileInputRef.current?.click()} className="flex-1 rounded-xl h-9 gap-1.5 text-xs">
                <Upload className="w-3.5 h-3.5" /> 上传
              </Button>
            </div>
            {onDemoIdentify && (
              <div className="space-y-1">
                <span className="text-[10px] text-muted-foreground font-medium">演示样本</span>
                <div className="flex gap-1.5">
                  {arMockResults.map((item) => (
                    <button key={item.mockImage} onClick={() => onDemoIdentify(item)}
                      className="flex-1 rounded-lg overflow-hidden border border-border/50 hover:border-primary/40 transition-colors group">
                      <div className="aspect-[4/3] overflow-hidden bg-secondary/50">
                        <img src={mockImageMap[item.mockImage]} alt={item.partName}
                          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200" />
                      </div>
                      <div className="py-0.5 bg-card">
                        <p className="text-[9px] font-semibold text-foreground text-center">{item.partIcon} {item.partName}</p>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      {/* Hidden file inputs */}
      <input ref={cameraInputRef} type="file" accept="image/*" capture="environment" className="hidden" onChange={handleFileChange} />
      <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleFileChange} />

      {/* Input bar */}
      <div
        className={cn(
          "pt-1",
          variant === "main" ? "pb-20" : variant === "drawer" ? "pb-6" : "pb-0",
        )}
      >
        <div className="flex items-center gap-1.5 glass-panel rounded-2xl px-2.5 py-2">
          {/* Photo/upload button */}
          <button
            onClick={() => onTogglePhotoMenu?.(!showPhotoMenu)}
            className={cn("p-1.5 rounded-full transition-colors flex-shrink-0",
              showPhotoMenu ? "text-primary bg-primary/10" : "text-muted-foreground hover:text-primary")}
          >
            <ImagePlus className="w-5 h-5" />
          </button>

          {voiceMode ? (
            <button
              type="button"
              onPointerDown={(e) => {
                if (voiceDisabled) return;
                e.preventDefault();
                e.currentTarget.setPointerCapture?.(e.pointerId);
                startVoiceHold();
              }}
              onPointerUp={(e) => {
                e.preventDefault();
                if (e.currentTarget.hasPointerCapture?.(e.pointerId)) {
                  e.currentTarget.releasePointerCapture(e.pointerId);
                }
                finishVoiceHold({ submit: true });
              }}
              onPointerCancel={(e) => {
                e.preventDefault();
                finishVoiceHold({ submit: false });
              }}
              onLostPointerCapture={() => finishVoiceHold({ submit: false })}
              onKeyDown={(e) => {
                if (voiceDisabled || e.repeat || (e.key !== " " && e.key !== "Enter")) return;
                e.preventDefault();
                startVoiceHold();
              }}
              onKeyUp={(e) => {
                if (e.key !== " " && e.key !== "Enter") return;
                e.preventDefault();
                finishVoiceHold({ submit: true });
              }}
              onBlur={() => finishVoiceHold({ submit: false })}
              onContextMenu={(e) => e.preventDefault()}
              disabled={voiceDisabled}
              aria-pressed={speechListening}
              aria-label={speechListening ? "松开填入语音输入" : "按住说话"}
              title={speechListening ? "松开填入输入框" : "按住说话"}
              className={cn(
                "flex-1 min-w-0 h-8 rounded-full px-3 text-sm font-medium transition-colors duration-200 touch-none select-none",
                "border border-transparent bg-primary/5 text-foreground",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40",
                speechPhase === "listening" && "border-[#e5cdd8] bg-[#f8eef3] text-[#563544] dark:border-[#7b4f61]/50 dark:bg-[#5a3445]/30 dark:text-[#f7e7ee]",
                voiceTranscribing && "border-[#e5cdd8] bg-[#f6edf1] text-[#6d4e5b] dark:border-[#7b4f61]/50 dark:bg-[#5a3445]/25 dark:text-[#f7e7ee]",
                voiceDisabled && "opacity-50",
              )}
            >
              <span className="block truncate">{voiceHoldLabel}</span>
            </button>
          ) : (
            <Input
              value={value}
              onChange={(e) => onChange(e.target.value)}
              onPaste={handlePaste}
              onKeyDown={(e) => {
                if (e.key !== "Enter" || speechListening) return;
                const nativeEvent = e.nativeEvent as KeyboardEvent & { isComposing?: boolean };
                const compositionJustEnded =
                  compositionEndAtRef.current > 0 && Date.now() - compositionEndAtRef.current < 120;
                if (composingRef.current || nativeEvent.isComposing || e.keyCode === 229 || compositionJustEnded) {
                  compositionEndAtRef.current = 0;
                  return;
                }
                compositionEndAtRef.current = 0;
                if (!value.trim() && !canSendWithoutText && !sendLoading) return;
                e.preventDefault();
                onSend();
              }}
              onCompositionStart={() => {
                composingRef.current = true;
                compositionEndAtRef.current = 0;
              }}
              onCompositionEnd={() => {
                composingRef.current = false;
                compositionEndAtRef.current = Date.now();
              }}
              placeholder={voiceTranscribing ? "正在整理语音..." : placeholder}
              readOnly={speechListening}
              className="flex-1 border-0 bg-transparent focus-visible:ring-0 text-sm h-8 px-1"
            />
          )}

          {/* Voice button：点击切换语音模式；真正录音由中间“按住说话”按钮触发。 */}
          <button
            type="button"
            onClick={toggleVoiceMode}
            disabled={voiceDisabled}
            aria-pressed={voiceMode}
            aria-label={voiceMode ? "切换到文字输入" : "切换到语音输入"}
            title={voiceMode ? "切换到文字输入" : "切换到语音输入"}
            className={cn(
              "p-1.5 rounded-full flex-shrink-0 transition-colors duration-200 touch-none select-none",
              speechPhase === "listening"
                ? "bg-[#8b5870] text-white shadow-sm dark:bg-[#9a6d7f] dark:text-white"
                : voiceTranscribing
                  ? "bg-[#b98ba0] text-white shadow-sm dark:bg-[#9a6d7f] dark:text-white"
                  : voiceMode
                  ? "bg-primary/10 text-primary"
                : "text-muted-foreground hover:text-primary bg-transparent",
              voiceDisabled && "opacity-40",
            )}
          >
            <VoiceToggleIcon className="w-5 h-5" />
          </button>

          {/* Send：空输入且 sendLoading 时用于停止；有内容时即使生成中也作为新一轮发送。 */}
          <Button
            type="button"
            onClick={onSend}
            size="icon"
            variant={sendLooksActive ? "default" : "secondary"}
            className={cn(
              "w-8 h-8 rounded-full flex-shrink-0",
              !sendLooksActive && "bg-muted text-muted-foreground shadow-none hover:bg-muted hover:text-muted-foreground",
            )}
            disabled={disabled}
            aria-busy={sendLoading}
            title={sendIsStop ? "停止回复" : "发送"}
          >
            {sendIsStop ? (
              <Square className="w-3.5 h-3.5 fill-current text-primary-foreground" aria-hidden />
            ) : (
              <Send className={cn("w-4 h-4", !sendLooksActive && "text-muted-foreground")} />
            )}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default MaiInputBar;
