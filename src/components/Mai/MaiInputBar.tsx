import React, { useRef } from "react";
import { Send, Mic, Camera, Upload, ImagePlus, X, Square } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { arMockResults } from "@/data/deviceMockData";
import type { PhotoIdentifyResult } from "@/data/deviceMockData";
import mockDuckbillImg from "@/assets/mock-duckbill.jpg";
import mockFlangeImg from "@/assets/mock-flange.jpg";
import mockSealImg from "@/assets/mock-seal.jpg";

const mockImageMap: Record<string, string> = {
  duckbill: mockDuckbillImg,
  flange: mockFlangeImg,
  seal: mockSealImg,
};

interface MaiInputBarProps {
  value: string;
  onChange: (val: string) => void;
  onSend: () => void;
  onVoice?: () => void;
  onPhotoFile?: (file: File) => void;
  onDemoIdentify?: (result: PhotoIdentifyResult) => void;
  /** 正在语音听写：高亮麦克风并让输入框只读，避免与流式转写互相覆盖 */
  speechListening?: boolean;
  /** Hub 等设备：发送后对话流进行中时为 true（显示加载图标；再次点击 onSend 由父级处理打断） */
  sendLoading?: boolean;
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
  onVoice,
  onPhotoFile,
  onDemoIdentify,
  speechListening = false,
  sendLoading = false,
  disabled = false,
  placeholder = "和 M.ai 聊聊...",
  showPhotoMenu = false,
  onTogglePhotoMenu,
  className,
  variant = "main",
}) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);
  const composingRef = useRef(false);
  const compositionEndAtRef = useRef(0);
  /** 有文字或生成中（打断）时用主色发送键；仅空且非加载时置灰样式 */
  const sendLooksActive = value.trim().length > 0 || sendLoading;

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file && onPhotoFile) onPhotoFile(file);
    e.target.value = "";
  };

  return (
    <div className={cn("flex-shrink-0", className)}>
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

          <Input
            value={value}
            onChange={(e) => onChange(e.target.value)}
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
              if (!value.trim() && !sendLoading) return;
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
            placeholder={placeholder}
            readOnly={speechListening}
            className="flex-1 border-0 bg-transparent focus-visible:ring-0 text-sm h-8 px-1"
          />

          {/* Voice button：听写中为饱和绿色+白图标，结束恢复默认灰/悬停主题色 */}
          <button
            type="button"
            onClick={() => onVoice?.()}
            disabled={!onVoice}
            aria-pressed={speechListening}
            title={speechListening ? "正在录制语音，点击结束" : "点击开始语音输入"}
            className={cn(
              "p-1.5 rounded-full flex-shrink-0 transition-colors duration-200",
              speechListening
                ? "bg-emerald-600 text-white shadow-sm dark:bg-emerald-500 dark:text-white"
                : "text-muted-foreground hover:text-primary bg-transparent",
              !onVoice && "opacity-40",
            )}
          >
            <Mic className="w-5 h-5" />
          </button>

          {/* Send：sendLoading 时保留可点以便父组件实现「再次点击打断」；空内容时仅视觉置灰，不禁用以保持父级逻辑一致 */}
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
            title={sendLoading ? "停止回复" : "发送"}
          >
            {sendLoading ? (
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
