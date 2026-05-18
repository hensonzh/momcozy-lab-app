import React, { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Mic, Send } from "lucide-react";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { formatVol, unitLabel } from "@/lib/volumeUnit";
import { useVolumeUnit } from "@/lib/volumeUnit";
import { useBargeIn } from "@/hooks/useBargeIn";
import type { PumpRecord } from "@/data/mockData";

interface Msg {
  id: string;
  role: "mai" | "user";
  content: string;
  isCard?: boolean;
}

interface RecordAgentDrawerProps {
  open: boolean;
  onClose: () => void;
  todayRecords: PumpRecord[];
  todayTotal: number;
  onAddRecord: (record: PumpRecord) => void;
}

const RecordAgentDrawer: React.FC<RecordAgentDrawerProps> = ({
  open, onClose, todayRecords, todayTotal, onAddRecord,
}) => {
  const [input, setInput] = useState("");
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [awaitingFlow, setAwaitingFlow] = useState<string | null>(null);
  const [streaming, setStreaming] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const initialized = useRef(false);
  const [volUnit] = useVolumeUnit();
  const { track, interrupt } = useBargeIn();

  useEffect(() => {
    if (open && !initialized.current) {
      initialized.current = true;
      const lastRec = todayRecords[todayRecords.length - 1];
      const greeting: Msg = {
        id: "greet",
        role: "mai",
        content: `妈妈你好~ 今天目前已记录 ${todayRecords.length} 次，共 ${formatVol(todayTotal, volUnit)}${unitLabel(volUnit)}，继续加油哦！💕`,
      };
      const summary: Msg | null = lastRec
        ? {
            id: "summary",
            role: "mai",
            content: `📋 最近一次记录：${lastRec.time}，${formatVol(lastRec.totalMl, volUnit)}${unitLabel(volUnit)}${lastRec.durationMin > 0 ? `，${lastRec.durationMin}分钟` : ""}（${lastRec.source === "device" ? "设备同步" : lastRec.source === "voice" ? "M.ai代记" : "手动"}）`,
            isCard: true,
          }
        : null;
      setMsgs(summary ? [greeting, summary] : [greeting]);
    }
    if (!open) {
      initialized.current = false;
    }
  }, [open, todayRecords, todayTotal, volUnit]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [msgs]);

  const pushMai = (content: string, isCard?: boolean) => {
    setStreaming(true);
    const tid = setTimeout(() => {
      setMsgs((p) => [...p, { id: `m${Date.now()}`, role: "mai", content, isCard }]);
      setStreaming(false);
    }, 600);
    track(tid);
  };

  // Compute breakdown for trend analysis
  const getBreakdown = () => {
    const deviceMl = todayRecords.filter(r => r.source === "device").reduce((s, r) => s + r.totalMl, 0);
    const manualMl = todayRecords.filter(r => r.subLabel === "补录" && r.source !== "device").reduce((s, r) => s + r.totalMl, 0);
    return { deviceMl, manualMl };
  };

  const handlePill = (key: string) => {
    if (key === "record") {
      setMsgs((p) => [...p, { id: `u${Date.now()}`, role: "user", content: "我要吸奶补录" }]);
      pushMai("好的～吸奶补录是指通过吸奶器以外的方式获取的自己生产的母乳，会计入可用母乳库存中。\n\n请告诉我补录的毫升数，例如「80ml」");
      setAwaitingFlow("record");
    } else if (key === "trend") {
      setMsgs((p) => [...p, { id: `u${Date.now()}`, role: "user", content: "分析可用母乳库存趋势" }]);
      const { deviceMl, manualMl } = getBreakdown();
      pushMai(`📊 可用母乳库存分析：\n\n你的可用母乳库存由以下部分组成：\n🔹 吸奶器记录：${formatVol(deviceMl, volUnit)}${unitLabel(volUnit)}\n🔹 手动背奶补录：${formatVol(manualMl, volUnit)}${unitLabel(volUnit)}\n📦 合计：${formatVol(todayTotal, volUnit)}${unitLabel(volUnit)}\n\n最近7日奶量整体呈上升趋势，乳汁分泌稳定，建议保持当前吸奶频率。如果感觉有涨奶不适，可以适当增加一次排空。\n\n有什么具体疑问吗？我来帮你解答 💪`);
      setAwaitingFlow(null);
    }
  };

  const handleSend = () => {
    if (!input.trim()) return;
    if (streaming) {
      interrupt();
      setStreaming(false);
      setMsgs((p) => [...p, { id: `int-${Date.now()}`, role: "mai", content: "── 用户打断输出 ──" }]);
    }
    const text = input.trim();
    setMsgs((p) => [...p, { id: `u${Date.now()}`, role: "user", content: text }]);
    setInput("");

    if (awaitingFlow === "record") {
      const mlMatch = text.match(/(\d+)\s*(?:ml|毫升)?/i);

      if (mlMatch) {
        const val = parseInt(mlMatch[1]);
        const rec: PumpRecord = {
          id: `mai-${Date.now()}`,
          date: "2026-03-09",
          time: new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }),
          durationMin: 0, leftMl: Math.round(val / 2), rightMl: Math.ceil(val / 2),
          totalMl: val, source: "voice", mode: "deep", subLabel: "补录",
          category: "inventory",
        };
        onAddRecord(rec);
        pushMai(`✅ 已帮你吸奶补录 ${val}ml，标记为「来自M.ai」，已计入可用母乳库存。今日总库存已更新～ 💕`);
        setAwaitingFlow(null);
      } else {
        pushMai("请告诉我具体毫升数哦～ 例如「80ml」或直接输入数字");
      }
    } else {
      pushMai(`收到～关于「${text}」，我来看看你的数据... 你今天表现很棒哦 💕`);
    }
  };

  const pills = [
    { label: "🤱 补录奶量", key: "record" },
    { label: "📈 趋势奶量咨询", key: "trend" },
  ];

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-40 bg-foreground/20 backdrop-blur-sm"
            onClick={onClose}
          />
          <motion.div
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", damping: 28, stiffness: 300 }}
            className="fixed inset-x-0 bottom-16 z-40 h-[60vh] rounded-t-3xl bg-card border-t border-border shadow-2xl flex flex-col"
          >
            <div className="flex justify-center pt-2 pb-1">
              <div className="w-10 h-1 rounded-full bg-border" />
            </div>

            <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-2 space-y-2.5">
              {msgs.map((m) =>
                m.content === "── 用户打断输出 ──" ? (
                  <div key={m.id} className="text-center py-0.5">
                    <span className="text-[10px] text-muted-foreground italic">── 用户打断输出 ──</span>
                  </div>
                ) : (
                  <div key={m.id} className={cn("flex gap-2", m.role === "user" ? "flex-row-reverse" : "flex-row")}>
                    <div
                      className={cn(
                        "max-w-[80%] rounded-2xl px-3.5 py-2.5 text-[13px] leading-relaxed whitespace-pre-line",
                        m.role === "user"
                          ? "bg-primary text-primary-foreground rounded-br-md"
                          : m.isCard
                            ? "bg-secondary border border-border rounded-bl-md text-foreground"
                            : "bg-secondary/60 border border-border/50 rounded-bl-md text-foreground"
                      )}
                    >
                      {m.content}
                    </div>
                  </div>
                )
              )}
            </div>

            <div className="flex-shrink-0 px-4 py-2 flex flex-wrap gap-2">
              {pills.map((p) => (
                <button
                  key={p.key}
                  onClick={() => handlePill(p.key)}
                  className="px-3 py-1.5 rounded-full bg-secondary text-secondary-foreground text-[11px] font-semibold whitespace-nowrap hover:bg-accent transition-colors"
                >
                  {p.label}
                </button>
              ))}
            </div>

            <div className="flex-shrink-0 px-4 pb-6 pt-1">
              <div className="flex items-center gap-2 glass-panel rounded-2xl px-3 py-2">
                <Input
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && handleSend()}
                  placeholder="对 M.ai 说..."
                  className="flex-1 border-0 bg-transparent focus-visible:ring-0 text-sm h-8 px-1"
                />
                <button className="p-1.5 rounded-full text-muted-foreground hover:text-primary transition-colors">
                  <Mic className="w-5 h-5" />
                </button>
                <Button onClick={handleSend} size="icon" className="w-8 h-8 rounded-full">
                  <Send className="w-4 h-4" />
                </Button>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default RecordAgentDrawer;
