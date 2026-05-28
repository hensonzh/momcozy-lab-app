import React, { useState, useEffect, useRef, forwardRef, useImperativeHandle } from "react";
import { motion, AnimatePresence } from "framer-motion";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { cn } from "@/lib/utils";
import { useBargeIn } from "@/hooks/useBargeIn";
import { todaySchedule, dailySummary, type ScheduleTask } from "@/data/mockData";
import { refreshTodayTasks } from "@/data/planMockData";
import { CheckCircle2, Clock, Bot, AlertTriangle } from "lucide-react";
import { Badge } from "@/components/ui/badge";

/* ── Types ── */
interface ChatMsg {
  id: string;
  role: "mai" | "user";
  content: string;
  type?: "text" | "choice" | "task-list" | "phase-card" | "goal-card" | "summary-card" | "blocked-card";
  choiceOptions?: { label: string; action: string }[];
  tasks?: ScheduleTask[];
}

export interface InlineScheduleFlowHandle {
  handleExternalInput: (text: string) => boolean;
}

interface Props {
  onComplete?: () => void;
  initialAction?: string; // e.g. "view-tasks", "add-avoidance", "screenshot-schedule", "day-summary"
}

/* ── Data ── */
const milkyPhases = [
  { key: "colostrum", label: "初乳期", detail: "0-3天", active: false },
  { key: "establish", label: "建立期", detail: "1-4周", active: false },
  { key: "stable", label: "稳产期", detail: "1-6月 ✅ 当前", active: true },
  { key: "weaning", label: "离乳期", detail: "6月+", active: false },
];

const addMinutes = (time: string, mins: number): string => {
  const [h, m] = time.split(":").map(Number);
  const total = h * 60 + m + mins;
  return `${String(Math.floor(total / 60) % 24).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
};

/* ── Component ── */
const InlineScheduleFlow = forwardRef<InlineScheduleFlowHandle, Props>(({ onComplete, initialAction }, ref) => {
  const [msgs, setMsgs] = useState<ChatMsg[]>([]);
  const [streaming, setStreaming] = useState(false);
  const [localTasks, setLocalTasks] = useState<ScheduleTask[]>([...todaySchedule]);
  const [blockedSlots, setBlockedSlots] = useState<{ title: string; start: string; end: string }[]>([]);
  const [awaitingInput, setAwaitingInput] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const { track, interrupt } = useBargeIn();

  /** Persist task changes so Schedule page picks them up */
  const syncTasksToSchedule = (tasks: ScheduleTask[]) => {
    const maiTasks = tasks.filter((t) => t.source === "mai");
    const existing = JSON.parse(localStorage.getItem("chaseMilkTasks") || "[]");
    // Merge: replace by id, append new
    const existingIds = new Set(existing.map((t: any) => t.id));
    const merged = [
      ...existing.filter((t: any) => !maiTasks.find((m) => m.id === t.id)),
      ...maiTasks.filter((t) => !existingIds.has(t.id) || existing.find((e: any) => e.id === t.id)),
    ];
    localStorage.setItem("chaseMilkTasks", JSON.stringify(merged));
    window.dispatchEvent(new Event("chaseMilkUpdated"));
    refreshTodayTasks();
  };

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [msgs]);

  const pushMsg = (msg: ChatMsg) => setMsgs((p) => [...p, msg]);
  const pushUser = (content: string) => pushMsg({ id: `u${Date.now()}`, role: "user", content });

  const pushMai = (content: string, extra?: Partial<ChatMsg>) => {
    setStreaming(true);
    const tid = setTimeout(() => {
      setStreaming(false);
      pushMsg({ id: `m${Date.now()}`, role: "mai", content, ...extra });
    }, 600);
    track(tid);
  };

  // Init
  useEffect(() => {
    if (initialAction) {
      // Directly trigger the specific action
      setTimeout(() => handleChoice(initialAction), 100);
    } else {
      const avg = Math.round(dailySummary.reduce((s, d) => s + d.total, 0) / dailySummary.length);
      pushMai(
        `好的，来看看你的日程规划吧～ 📅\n\n📌 当前阶段：稳产期（产后12周）\n🎯 今日任务：${todaySchedule.length} 项\n📊 7日均奶量：${avg}ml/天\n\n你想做什么呢？`,
        {
          type: "choice",
          choiceOptions: [
            { label: "📋 查看今日任务", action: "view-tasks" },
            { label: "⛔ 添加避开时段", action: "add-avoidance" },
            { label: "📸 截图识别日程", action: "screenshot-schedule" },
            { label: "📊 查看日结", action: "day-summary" },
          ],
        }
      );
    }
  }, []);

  useImperativeHandle(ref, () => ({
    handleExternalInput: (text: string) => {
      if (!awaitingInput) return false;
      handleTextInput(text);
      return true;
    },
  }));

  const handleTextInput = (text: string) => {
    pushUser(text);
    if (awaitingInput === "avoidance-text") {
      setAwaitingInput(null);
      // Parse simple time reference
      const newSlot = { title: text, start: "14:00", end: "15:00" };
      setBlockedSlots((p) => [...p, newSlot]);

      // Adjust conflicting tasks
      const adjusted = localTasks.map((t) => {
        if (t.type === "pump" && t.time >= newSlot.start && t.time < newSlot.end) {
          return { ...t, time: addMinutes(newSlot.start, -30), adjusted: "因避开时段提前" };
        }
        return t;
      }).sort((a, b) => a.time.localeCompare(b.time));
      setLocalTasks(adjusted);
      syncTasksToSchedule(adjusted);

      pushMai(
        `收到！已将「${text}」标记为避开时段 ✅\n\n受影响的吸乳任务已自动调整：\n• 🍼 冲突任务 → 提前至避开时段前30分钟\n• 📅 后续任务已重新排列\n\n调整后的日程已就绪，安心去忙吧～ 💕`,
        {
          type: "choice",
          choiceOptions: [
            { label: "📋 查看调整后的任务", action: "view-tasks" },
            { label: "⛔ 继续添加避开时段", action: "add-avoidance" },
            { label: "✅ 完成规划", action: "done" },
          ],
        }
      );
    } else if (awaitingInput === "ocr-text") {
      setAwaitingInput(null);
      pushMai(
        `收到您的日程信息～ 📸\n\n我已识别到以下需要避开的时段：\n⛔ **14:00-15:00** ${text}\n\n已帮你自动调整排程：\n• 🍼 午后吸乳 → 提前至13:30\n• ⚠️ 后续任务已顺延调整\n\n需要确认应用吗？`,
        {
          type: "choice",
          choiceOptions: [
            { label: "💡 确认应用", action: "ocr-confirm" },
            { label: "💡 再调整一下", action: "ocr-adjust" },
          ],
        }
      );
    } else {
      // Generic fallback
      pushMai(
        `收到～关于「${text}」，我会帮你调整排程。有其他需要规划的吗？`,
        {
          type: "choice",
          choiceOptions: [
            { label: "📋 查看今日任务", action: "view-tasks" },
            { label: "✅ 完成规划", action: "done" },
          ],
        }
      );
    }
  };

  const handleChoice = (action: string) => {
    switch (action) {
      case "view-tasks": {
        pushUser("查看今日任务");
        const done = localTasks.filter((t) => t.done).length;
        pushMai(
          `📋 今日共 ${localTasks.length} 项任务，已完成 ${done} 项：`,
          {
            type: "task-list",
            tasks: localTasks,
            choiceOptions: [
              { label: "⏰ 顺延下一个任务", action: "delay-next" },
              { label: "⛔ 添加避开时段", action: "add-avoidance" },
              { label: "📊 查看日结", action: "day-summary" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "view-phase": {
        pushUser("查看泌乳周期");
        pushMai(
          "🌌 你当前的 Milky.Way 泌乳周期：",
          {
            type: "phase-card",
            choiceOptions: [
              { label: "🎯 调整泌乳目标", action: "goal-adjust" },
              { label: "📋 查看今日任务", action: "view-tasks" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "goal-adjust": {
        pushUser("泌乳目标调整");
        const avg = Math.round(dailySummary.reduce((s, d) => s + d.total, 0) / dailySummary.length);
        const cardContent = dailySummary.map((d) => `${d.date}: ${d.total}ml (${d.sessions}次)`).join("\n");
        pushMai(
          `📊 近7天奶量记录：\n${cardContent}\n\n日均 ${avg}ml，波动在正常范围内 🌊\n\n你想怎么调整目标呢？`,
          {
            type: "goal-card",
            choiceOptions: [
              { label: "💪 我想增加奶量", action: "goal-increase" },
              { label: "👌 维持现状就好", action: "goal-maintain" },
              { label: "🌸 准备逐步减量", action: "goal-decrease" },
            ],
          }
        );
        break;
      }
      case "goal-increase": {
        pushUser("我想增加奶量");
        pushMai(
          "了解你想增奶的想法 💪\n\n在调整之前确认一下：是因为宝宝需求增加了，还是想储备更多母乳？\n\n⚠️ 增奶注意事项：\n• 增加排空频率初期可能会疲劳\n• 需要保证充足水分和营养\n• 建议1-2周后评估效果\n\n确认要调整吗？",
          {
            type: "choice",
            choiceOptions: [
              { label: "✅ 确认，帮我调整", action: "goal-increase-confirm" },
              { label: "🤔 算了，先不改", action: "goal-cancel" },
            ],
          }
        );
        break;
      }
      case "goal-decrease": {
        pushUser("准备逐步减量");
        pushMai(
          "了解你想减量的想法 🌸\n\n⚠️ 减量注意事项：\n• 减量过快可能引起涨奶、堵奶\n• 建议每3-5天减少1次排空\n• 出现硬块或疼痛请暂停并就医\n\n确认要调整吗？",
          {
            type: "choice",
            choiceOptions: [
              { label: "✅ 确认，帮我调整", action: "goal-decrease-confirm" },
              { label: "🤔 算了，先不改", action: "goal-cancel" },
            ],
          }
        );
        break;
      }
      case "goal-increase-confirm": {
        pushUser("确认，帮我调整");
        // Add a chase-milk task
        const newTask: ScheduleTask = {
          id: `s-chase-${Date.now()}`,
          time: "16:00",
          type: "pump",
          title: "下午加排（增量）",
          done: false,
          source: "mai",
          reason: "追奶",
        };
        const updatedInc = [...localTasks, newTask].sort((a, b) => a.time.localeCompare(b.time));
        setLocalTasks(updatedInc);
        syncTasksToSchedule(updatedInc);
        pushMai(
          "已确认调整！ ✅\n\n泌乳目标更新为「追奶」：\n• 每日增加1次排空（约每3小时一次）\n• 夜间保留至少1次\n• 已在日程中添加「16:00 下午加排」\n\n预计1-2周后看到变化，有不适随时找 Mai 💕",
          {
            type: "choice",
            choiceOptions: [
              { label: "📋 查看调整后的任务", action: "view-tasks" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "goal-decrease-confirm": {
        pushUser("确认，帮我调整");
        // Remove the earliest non-done pump task
        const idx = localTasks.findIndex((t) => t.type === "pump" && !t.done && t.source === "mai");
        const updatedDec = idx >= 0 ? localTasks.filter((_, i) => i !== idx) : [...localTasks];
        setLocalTasks(updatedDec);
        syncTasksToSchedule(updatedDec);
        pushMai(
          "已确认调整！ ✅\n\n泌乳目标更新为「温和离乳」：\n• 每3-5天减少1次排空\n• 每次缩短2-3分钟\n• 已移除一项追奶任务\n\n过程中有不适随时找 Mai 调整回来 💕",
          {
            type: "choice",
            choiceOptions: [
              { label: "📋 查看调整后的任务", action: "view-tasks" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "goal-maintain": {
        pushUser("维持现状就好");
        const avg = Math.round(dailySummary.reduce((s, d) => s + d.total, 0) / dailySummary.length);
        pushMai(
          `好的，维持现有节奏就很棒！ 👍\n\n你目前日均约 ${avg}ml，非常稳定。我会继续帮你监控波动，有异常会提醒你的～`,
          {
            type: "choice",
            choiceOptions: [
              { label: "📋 查看今日任务", action: "view-tasks" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "goal-cancel": {
        pushUser("算了，先不改了");
        pushMai(
          "完全没问题！🤗\n\n目前的奶量节奏其实很好的，保持现状也是很棒的选择。有任何变化随时来找 Mai 聊聊 💕",
          {
            type: "choice",
            choiceOptions: [
              { label: "📋 查看今日任务", action: "view-tasks" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "add-avoidance": {
        pushUser("添加避开时段");
        setAwaitingInput("avoidance-text");
        pushMai(
          "好的～请告诉我需要避开的时间段和事项 📅\n\n例如：\n• 「明天14:00-15:00有会议」\n• 「下午外出2小时」\n• 「晚上有朋友聚餐」\n\n我来帮你重新规划吸乳和喂奶安排，确保不冲突 💪"
        );
        break;
      }
      case "delay-next": {
        pushUser("顺延下一个任务");
        const nextUndone = localTasks.find((t) => !t.done && t.type !== "meeting");
        if (nextUndone) {
          const newTime = addMinutes(nextUndone.time, 30);
          const updatedDelay = localTasks.map((t) =>
            t.id === nextUndone.id ? { ...t, time: newTime, adjusted: "顺延半小时" } : t
          ).sort((a, b) => a.time.localeCompare(b.time));
          setLocalTasks(updatedDelay);
          syncTasksToSchedule(updatedDelay);
          pushMai(
            `已将「${nextUndone.title}」从 ${nextUndone.time} 顺延至 ${newTime} ⏰\n\n后续任务也已自动调整，不用担心冲突哦～`,
            {
              type: "choice",
              choiceOptions: [
                { label: "📋 查看调整后的任务", action: "view-tasks" },
                { label: "⏰ 继续顺延", action: "delay-next" },
                { label: "✅ 完成规划", action: "done" },
              ],
            }
          );
        } else {
          pushMai("所有任务已完成或无法顺延哦～ 🎉", {
            type: "choice",
            choiceOptions: [{ label: "✅ 完成规划", action: "done" }],
          });
        }
        break;
      }
      case "day-summary": {
        pushUser("查看日结");
        const done = localTasks.filter((t) => t.done).length;
        const total = localTasks.length;
        const totalMl = dailySummary[dailySummary.length - 1]?.total || 0;
        pushMai(
          `📊 今日日结预览：\n\n✅ 已完成：${done}/${total} 项任务\n🍼 今日产量：${totalMl}ml\n⏱️ 完成率：${Math.round((done / total) * 100)}%\n\n${done >= total * 0.7 ? "今天表现很棒！🏅" : "继续加油，你做得很好！💪"}\n\nMai 会在一天结束时为你生成完整的日结报告哦～`,
          {
            type: "summary-card",
            choiceOptions: [
              { label: "📋 查看任务详情", action: "view-tasks" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "ocr-confirm": {
        pushUser("确认应用");
        syncTasksToSchedule(localTasks);
        pushMai(
          "好的，已帮你更新排程！ ✅\n\n所有冲突任务已自动调整并同步到呵护计划 💕",
          {
            type: "choice",
            choiceOptions: [
              { label: "📋 查看今日任务", action: "view-tasks" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "ocr-adjust": {
        pushUser("再调整一下");
        setAwaitingInput("ocr-text");
        pushMai("好的～你希望怎么调整呢？可以告诉我具体想要的时间安排 🌟");
        break;
      }
      case "screenshot-schedule": {
        pushUser("截图识别日程");
        setAwaitingInput("ocr-text");
        pushMai(
          "请发送你的日程截图或文字描述 📸\n\n例如发送钉钉/飞书日历的截图，或直接告诉我：\n「14:00-15:00 团队周会，16:00-17:00 客户会议」\n\n我会自动识别并帮你调整吸乳排程 ✨"
        );
        break;
      }
      case "more-options": {
        pushMai(
          "还有这些功能可以帮到你～ 🌟",
          {
            type: "choice",
            choiceOptions: [
              { label: "📸 截图识别日程", action: "screenshot-schedule" },
              { label: "📊 查看日结", action: "day-summary" },
              { label: "⏰ 顺延下一个任务", action: "delay-next" },
              { label: "✅ 完成规划", action: "done" },
            ],
          }
        );
        break;
      }
      case "done": {
        pushUser("完成规划");
        pushMai(
          "日程规划完毕！ 🎉\n\n今天的任务安排已就绪，我会在每个时间节点提醒你。有任何变化随时来找 Mai 调整哦～\n\n做妈妈是一个充满 Effort 的旅程，让 Mai 帮你 Effort-Less, cozy~ 💕"
        );
        onComplete?.();
        break;
      }
      default:
        break;
    }
  };

  /* ── Renderers ── */
  const taskConf: Record<string, { icon: string }> = {
    pump: { icon: "🤱" },
    feed: { icon: "🍼" },
    meeting: { icon: "💼" },
  };

  const renderTaskList = (tasks: ScheduleTask[]) => (
    <div className="space-y-1 mt-2">
      {tasks.map((t) => {
        const conf = taskConf[t.type] || taskConf.pump;
        return (
          <div
            key={t.id}
            className={cn(
              "flex items-center gap-1.5 px-2 py-1 rounded-lg text-[11px]",
              t.type === "meeting" ? "bg-destructive/5 border border-destructive/20" : "bg-secondary/30"
            )}
          >
            <span className="font-mono font-bold text-muted-foreground w-9 shrink-0">{t.time}</span>
            <span>{conf.icon}</span>
            <span className={cn("flex-1 truncate font-medium", t.done ? "text-muted-foreground line-through" : "text-foreground")}>
              {t.title}
            </span>
            {t.done && <CheckCircle2 className="w-3 h-3 text-primary shrink-0" />}
            {t.source === "mai" && (
              <Badge variant="secondary" className="text-[7px] px-1 py-0 h-3 gap-0.5 bg-primary/10 text-primary border-primary/20 shrink-0">
                <Bot className="w-2 h-2" /> M.ai
              </Badge>
            )}
            {t.reason && (
              <Badge variant="outline" className="text-[7px] px-1 py-0 h-3 border-accent-foreground/20 text-accent-foreground/70 shrink-0">
                {t.reason}
              </Badge>
            )}
            {t.adjusted && (
              <span className="text-[8px] text-destructive font-semibold shrink-0">⚡</span>
            )}
          </div>
        );
      })}
    </div>
  );

  const renderPhaseCard = () => (
    <div className="flex items-center gap-0.5 mt-2">
      {milkyPhases.map((phase, i) => (
        <div
          key={phase.key}
          className={cn(
            "flex-1 rounded-lg py-1.5 px-1 text-center",
            phase.active ? "bg-primary text-primary-foreground" : "bg-secondary/60 text-muted-foreground"
          )}
        >
          <p className={cn("text-[10px] font-bold", phase.active && "text-primary-foreground")}>{phase.label}</p>
          <p className={cn("text-[8px] mt-0.5", phase.active ? "text-primary-foreground/70" : "text-muted-foreground/70")}>{phase.detail}</p>
        </div>
      ))}
    </div>
  );

  const renderMessage = (msg: ChatMsg) => {
    if (msg.content === "── 用户打断输出 ──") {
      return (
        <div key={msg.id} className="text-center py-0.5">
          <span className="text-[10px] text-muted-foreground italic">── 用户打断输出 ──</span>
        </div>
      );
    }
    const isMai = msg.role === "mai";
    return (
      <motion.div
        key={msg.id}
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        className={cn("flex gap-2", isMai ? "flex-row" : "flex-row-reverse")}
      >
        
        <div className={cn(
          "max-w-[85%] rounded-2xl px-3 py-2.5 text-[13px] leading-relaxed",
          isMai
            ? "bg-card border border-border rounded-bl-md"
            : "bg-primary text-primary-foreground rounded-br-md"
        )}>
          <p className="whitespace-pre-line">{msg.content}</p>

          {msg.type === "task-list" && msg.tasks && renderTaskList(msg.tasks)}
          {msg.type === "phase-card" && renderPhaseCard()}
          {msg.type === "goal-card" && (
            <div className="mt-2 p-2 rounded-lg bg-accent/30 border border-primary/20 text-[11px] font-mono whitespace-pre-line text-foreground">
              {dailySummary.map((d) => `${d.date}: ${d.total}ml (${d.sessions}次)`).join("\n")}
            </div>
          )}
          {msg.type === "summary-card" && (
            <div className="mt-2 text-center">
              <span className="text-2xl">🏅</span>
            </div>
          )}

          {msg.choiceOptions && msg.choiceOptions.length > 0 && (
            <div className="flex flex-wrap gap-1.5 mt-2.5">
              {msg.choiceOptions.map((opt) => (
                <button
                  key={opt.action}
                  onClick={() => handleChoice(opt.action)}
                  className="px-2.5 py-1 rounded-full bg-secondary text-secondary-foreground text-[11px] font-semibold hover:bg-accent transition-colors whitespace-nowrap"
                >
                  {opt.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </motion.div>
    );
  };

  return (
    <div className="w-full space-y-2.5">
      <div ref={scrollRef} className="space-y-2.5">
        <AnimatePresence mode="popLayout">
          {msgs.map(renderMessage)}
        </AnimatePresence>
      </div>

      {streaming && (
        <div className="flex gap-2 items-start">
          <div className="bg-card border border-border rounded-2xl rounded-bl-md px-3 py-2.5">
            <div className="flex gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-primary/50 animate-bounce" style={{ animationDelay: "0ms" }} />
              <span className="w-1.5 h-1.5 rounded-full bg-primary/50 animate-bounce" style={{ animationDelay: "150ms" }} />
              <span className="w-1.5 h-1.5 rounded-full bg-primary/50 animate-bounce" style={{ animationDelay: "300ms" }} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
});

InlineScheduleFlow.displayName = "InlineScheduleFlow";
export default InlineScheduleFlow;
