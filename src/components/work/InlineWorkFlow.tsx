import React, { useState, useEffect, useRef, forwardRef, useImperativeHandle } from "react";
import { motion, AnimatePresence } from "framer-motion";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { cn } from "@/lib/utils";
import { useBargeIn } from "@/hooks/useBargeIn";
import { toggleWorkPlan, setCurrentGoal, mockPlans, planColors, getActivePlanIds, refreshTodayTasks } from "@/data/planMockData";

/* ── Types ── */
interface ChatMsg {
  id: string;
  role: "mai" | "user";
  content: string;
  type?: "text" | "choice" | "plan-card" | "pack-card";
  choiceOptions?: { label: string; action: string }[];
}

export interface InlineWorkFlowHandle {
  handleExternalInput: (text: string) => boolean;
}

interface Props {
  onComplete?: () => void;
}

/* ── Stage machine ── */
type Stage =
  | "greeting"
  | "ask-return-date"
  | "ask-work-mode"
  | "ask-pump-env"
  | "ask-concern"
  | "assessing"
  | "result"
  | "show-pack"
  | "ask-adjust"
  | "adjust-confirm"
  | "done";

/* ── Mock work pack items ── */
const packItems = [
  { category: "背奶装备", items: ["Momcozy M.ai Pro 吸乳器", "储奶袋 ×30", "冰袋 ×2", "保温袋", "奶瓶 ×2"] },
  { category: "办公室必备", items: ["便携消毒器", "清洗液", "奶瓶刷", "一次性防溢乳垫 ×20", "遮挡披肩"] },
  { category: "妈妈能量", items: ["保温杯（饮水2L+）", "催奶茶/零食", "舒适哺乳内衣 ×3", "解压小物件"] },
  { category: "储存方案", items: ["标签贴纸（日期标记）", "冷藏分装盒", "家用储奶指南卡"] },
];

/* ── Component ── */
const InlineWorkFlow = forwardRef<InlineWorkFlowHandle, Props>(({ onComplete }, ref) => {
  const [msgs, setMsgs] = useState<ChatMsg[]>([]);
  const [stage, setStage] = useState<Stage>("greeting");
  const [streaming, setStreaming] = useState(false);
  const [awaitingInput, setAwaitingInput] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const { track, interrupt } = useBargeIn();

  // Collected data
  const [returnDate, setReturnDate] = useState("");
  const [workMode, setWorkMode] = useState("");
  const [pumpEnv, setPumpEnv] = useState("");
  const [concern, setConcern] = useState("");

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [msgs]);

  const pushMsg = (msg: ChatMsg) => setMsgs((p) => [...p, msg]);
  const pushUser = (content: string) => pushMsg({ id: `u${Date.now()}`, role: "user", content });
  const pushMai = (content: string, extra?: Partial<ChatMsg>) => {
    setStreaming(true);
    const tid = setTimeout(() => {
      pushMsg({ id: `m${Date.now()}`, role: "mai", content, ...extra });
      setStreaming(false);
    }, 600);
    track(tid);
  };

  // Check fertility conflict
  const hasFertilityConflict = () => {
    const active = getActivePlanIds();
    return active.includes("fertility");
  };

  // Init
  useEffect(() => {
    if (hasFertilityConflict()) {
      const conflictMsg: ChatMsg = {
        id: "conflict-1",
        role: "mai",
        content: "⚠️ 检测到你目前正在进行「待产计划」。\n\n返工计划与待产计划互斥，无法同时进行。如需启用返工计划，请先结束待产计划。\n\n如有疑问，随时来找 Mai 聊聊 💕",
      };
      setMsgs([conflictMsg]);
      setStage("done");
      onComplete?.();
      return;
    }

    const greet: ChatMsg = {
      id: "greet-1",
      role: "mai",
      content: "亲爱的妈妈，你好呀！💼💕\n\n准备重返职场了呢，真的很佩服你的勇气和决心！产后返工既是挑战也是新篇章，Mai 会全程陪伴你，帮你规划好工作与哺乳之间的平衡。\n\n你在工作上的努力和对宝宝的爱，都同样了不起 ✨",
    };
    setMsgs([greet]);
    setTimeout(() => {
      pushMai("先让 Mai 了解一下你的返工安排，方便为你量身定制背奶计划 📋\n\n你计划什么时候返工呢？", {
        type: "choice",
        choiceOptions: [
          { label: "已经返工了", action: "date-already" },
          { label: "1-2周内", action: "date-1-2w" },
          { label: "1个月内", action: "date-1m" },
          { label: "还没确定", action: "date-unknown" },
        ],
      });
      setStage("ask-return-date");
    }, 1200);
  }, []);

  const handleChoice = (action: string) => {
    switch (stage) {
      case "ask-return-date": {
        const labels: Record<string, string> = {
          "date-already": "已经返工了", "date-1-2w": "1-2周内", "date-1m": "1个月内", "date-unknown": "还没确定",
        };
        const label = labels[action] || action;
        setReturnDate(label);
        pushUser(label);

        const timeAdvice = action === "date-already"
          ? "已经开始返工了呀，辛苦啦！"
          : action === "date-unknown"
            ? "没关系，我们先做好准备！"
            : `${label}返工，时间正好可以做充分准备！`;

        pushMai(`${timeAdvice}\n\n了解一下你的工作形式，这会影响吸乳排程 🏢\n\n你的工作模式是？`, {
          type: "choice",
          choiceOptions: [
            { label: "全天坐班", action: "mode-office" },
            { label: "居家办公", action: "mode-remote" },
            { label: "混合办公", action: "mode-hybrid" },
            { label: "弹性/兼职", action: "mode-flex" },
          ],
        });
        setStage("ask-work-mode");
        break;
      }
      case "ask-work-mode": {
        const labels: Record<string, string> = {
          "mode-office": "全天坐班", "mode-remote": "居家办公", "mode-hybrid": "混合办公", "mode-flex": "弹性/兼职",
        };
        const label = labels[action] || action;
        setWorkMode(label);
        pushUser(label);

        const modeAdvice = action === "mode-remote"
          ? "居家办公对背奶妈妈来说很友好！"
          : action === "mode-office"
            ? "坐班的话，找到合适的吸奶空间很关键～"
            : "灵活的工作模式让排程更有弹性！";

        pushMai(`${modeAdvice}\n\n关于工作场所的吸奶条件，目前是什么情况呢？ 🏠`, {
          type: "choice",
          choiceOptions: [
            { label: "有母婴室", action: "env-room" },
            { label: "有独立办公室", action: "env-office" },
            { label: "需要找空间", action: "env-find" },
            { label: "还不确定", action: "env-unknown" },
          ],
        });
        setStage("ask-pump-env");
        break;
      }
      case "ask-pump-env": {
        const labels: Record<string, string> = {
          "env-room": "有母婴室", "env-office": "有独立办公室", "env-find": "需要找空间", "env-unknown": "还不确定",
        };
        const label = labels[action] || action;
        setPumpEnv(label);
        pushUser(label);

        let envAdvice = "";
        if (action === "env-room") envAdvice = "有母婴室太棒了！这是最理想的环境。";
        else if (action === "env-office") envAdvice = "独立办公室也很好，记得准备好遮挡和锁门哦。";
        else if (action === "env-find") envAdvice = "Mai 建议你提前和HR沟通，很多公司对哺乳妈妈有支持政策的。";
        else envAdvice = "没关系，Mai 会在计划中给你准备应对方案。";

        pushMai(`${envAdvice}\n\n最后一个问题：返工后你最担心的是什么呢？ 🤔`, {
          type: "choice",
          choiceOptions: [
            { label: "奶量下降", action: "concern-supply" },
            { label: "时间不够用", action: "concern-time" },
            { label: "储奶和运输", action: "concern-storage" },
            { label: "同事的眼光", action: "concern-social" },
          ],
        });
        setStage("ask-concern");
        break;
      }
      case "ask-concern": {
        const labels: Record<string, string> = {
          "concern-supply": "奶量下降", "concern-time": "时间不够用", "concern-storage": "储奶和运输", "concern-social": "同事的眼光",
        };
        const label = labels[action] || action;
        setConcern(label);
        pushUser(label);
        setStage("assessing");

        const reassurance: Record<string, string> = {
          "concern-supply": "奶量的稳定需要规律排空，Mai 会帮你安排好工作日的吸乳节奏。",
          "concern-time": "时间管理是关键，Mai 会帮你规划最高效的吸乳时间窗口。",
          "concern-storage": "储奶和运输是背奶的核心技能，计划里会详细指导。",
          "concern-social": "你做的是最自然的事情，不需要不好意思。越来越多的职场妈妈都在这样做！",
        };

        pushMai(`${reassurance[action] || ""}\n\n收到所有信息！Mai 正在为你生成专属返工计划，请稍等... ⏳`);

        setTimeout(() => {
          pushMsg({
            id: `plan-card-${Date.now()}`,
            role: "mai",
            content: "",
            type: "plan-card",
          });
          setTimeout(() => {
            pushMai("这是你的返工背奶装备清单，提前准备好可以让你从容应对每一天 🎒✨");
            setTimeout(() => {
              pushMsg({
                id: `pack-card-${Date.now()}`,
                role: "mai",
                content: "",
                type: "pack-card",
              });
              setTimeout(() => {
                pushMai("以上就是你的专属返工方案！ 🌟\n\n你觉得这个计划安排怎么样？需要调整吗？", {
                  type: "choice",
                  choiceOptions: [
                    { label: "很好，直接启用", action: "accept" },
                    { label: "需要调整一下", action: "adjust" },
                  ],
                });
                setStage("ask-adjust");
              }, 800);
            }, 600);
          }, 800);
        }, 1500);
        break;
      }
      case "ask-adjust": {
        if (action === "accept") {
          pushUser("很好，直接启用");
          syncPlanToSchedule();
          pushMai("太好了！返工计划已启用并同步到你的呵护计划中 🎉\n\n📅 今日任务已更新\n📊 Milestone 里程碑已刷新\n🗓️ 月历排期已同步\n\nMai 会全程陪伴你的职场哺乳之旅，工作日的每个吸乳时间点都会提醒你。加油，职场妈妈！💪✨", {
            type: "choice",
            choiceOptions: [{ label: "去查看呵护计划", action: "go-schedule" }],
          });
          setStage("done");
        } else {
          pushUser("需要调整一下");
          setAwaitingInput(true);
          pushMai("没问题！请告诉我你想调整的部分，比如：\n\n• 吸奶次数或时间安排\n• 增减某些准备物品\n• 调整工作日排程\n\n随意说，Mai 来帮你优化～ 💕");
          setStage("adjust-confirm");
        }
        break;
      }
      case "done": {
        if (action === "go-schedule") {
          pushUser("去查看呵护计划");
          window.dispatchEvent(new CustomEvent("navigate-to", { detail: "/schedule" }));
          onComplete?.();
        }
        break;
      }
    }
  };

  const handleChoiceWrapper = (action: string) => {
    if (action === "confirm-adjusted") {
      pushUser("确认启用");
      syncPlanToSchedule();
      pushMai("调整后的返工计划已启用 🎉\n\n已同步到呵护计划的今日任务、Milestone 和月历中。\n\n职场与母爱兼得，你做得到！Mai 随时在这里 💕💼", {
        type: "choice",
        choiceOptions: [{ label: "去查看呵护计划", action: "go-schedule" }],
      });
      setStage("done");
    } else if (action === "reconsider") {
      pushUser("再想想");
      pushMai("没关系，慢慢来～你随时可以回来继续规划。\n\n有任何想法都可以告诉 Mai 哦 💕");
      setStage("done");
      onComplete?.();
    } else {
      handleChoice(action);
    }
  };

  const handleTextInput = (text: string) => {
    if (stage === "adjust-confirm") {
      pushUser(text);
      setAwaitingInput(false);
      setTimeout(() => {
        pushMai(`好的，已根据你的反馈「${text}」调整了返工计划 ✅\n\n调整后的计划会更符合你的实际工作节奏。确认启用调整后的方案吗？`, {
          type: "choice",
          choiceOptions: [
            { label: "确认启用", action: "confirm-adjusted" },
            { label: "再想想", action: "reconsider" },
          ],
        });
        setStage("ask-adjust");
      }, 800);
      return true;
    }
    return false;
  };

  const syncPlanToSchedule = () => {
    toggleWorkPlan(true);
    setCurrentGoal({
      planId: "work",
      label: "返工计划",
      summary: `${returnDate}返工 · ${workMode} · ${pumpEnv} 💼`,
    });
    refreshTodayTasks();
  };

  useImperativeHandle(ref, () => ({
    handleExternalInput: (text: string) => {
      if (awaitingInput || stage === "adjust-confirm") {
        return handleTextInput(text);
      }
      return false;
    },
  }));

  /* ── Render helpers ── */
  const renderPlanCard = () => {
    const plan = mockPlans.find((p) => p.id === "work");
    const colors = planColors.work;
    if (!plan) return null;

    return (
      <div className={cn("rounded-xl border p-3 space-y-2", colors.bg, colors.border)}>
        <div className="flex items-center gap-2">
          <span className="text-lg">{plan.emoji}</span>
          <div>
            <p className={cn("text-[13px] font-bold", colors.text)}>专属返工计划</p>
            <p className="text-[10px] text-muted-foreground">
              {returnDate} · {workMode} · {pumpEnv}
            </p>
          </div>
        </div>
        <div className="space-y-1.5">
          {plan.milestones.map((ms, i) => (
            <div key={ms.id} className="flex items-start gap-2">
              <div className={cn(
                "w-5 h-5 rounded-full flex items-center justify-center text-[9px] font-bold shrink-0 mt-0.5",
                i === plan.currentMilestoneIndex ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
              )}>
                {i + 1}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-[11px] font-semibold text-foreground">{ms.label}</p>
                <p className="text-[9px] text-muted-foreground">{ms.durationWeeks}周 · 从 {ms.startDate.slice(5)} 开始</p>
                <div className="flex flex-wrap gap-1 mt-0.5">
                  {ms.tasks.map((t, ti) => (
                    <span key={ti} className="text-[8px] text-muted-foreground bg-background/60 rounded px-1 py-0.5">
                      {t.icon} {t.title}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  };

  const renderPackCard = () => (
    <div className={cn("rounded-xl border p-3 space-y-2", "border-violet-300 dark:border-violet-700 bg-violet-50 dark:bg-violet-900/20")}>
      <div className="flex items-center gap-2">
        <span className="text-lg">🎒</span>
        <p className={cn("text-[13px] font-bold", "text-violet-800 dark:text-violet-200")}>返工背奶装备清单</p>
      </div>
      <div className="grid grid-cols-2 gap-2">
        {packItems.map((cat) => (
          <div key={cat.category} className="space-y-0.5">
            <p className="text-[10px] font-bold text-foreground/80">{cat.category}</p>
            {cat.items.map((item, i) => (
              <p key={i} className="text-[9px] text-muted-foreground pl-1.5">• {item}</p>
            ))}
          </div>
        ))}
      </div>
    </div>
  );

  const renderMessage = (msg: ChatMsg) => {
    if (msg.type === "plan-card") {
      return (
        <motion.div key={msg.id} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="w-full">
          {renderPlanCard()}
        </motion.div>
      );
    }
    if (msg.type === "pack-card") {
      return (
        <motion.div key={msg.id} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="w-full">
          {renderPackCard()}
        </motion.div>
      );
    }

    const isMai = msg.role === "mai";
    return (
      <motion.div
        key={msg.id}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className={cn("flex gap-2", isMai ? "flex-row" : "flex-row-reverse")}
      >
        {isMai && <MaiAvatar emotion="encourage" size="xs" className="mt-1 shrink-0" />}
        <div className="max-w-[82%] space-y-1.5">
          <div className={cn(
            "rounded-2xl px-3 py-2 text-[12px] leading-relaxed whitespace-pre-line",
            isMai
              ? "bg-secondary/60 border border-border/50 rounded-bl-md text-foreground"
              : "bg-primary text-primary-foreground rounded-br-md"
          )}>
            {msg.content}
          </div>
          {msg.type === "choice" && msg.choiceOptions && (
            <div className="flex flex-wrap gap-1.5">
              {msg.choiceOptions.map((opt) => (
                <button
                  key={opt.action}
                  onClick={() => handleChoiceWrapper(opt.action)}
                  className="px-2.5 py-1 rounded-full bg-primary/10 text-primary text-[10px] font-semibold hover:bg-primary/20 transition-colors border border-primary/20"
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
    <div className={cn("rounded-2xl border overflow-hidden", "border-violet-200 dark:border-violet-800 bg-violet-50/50 dark:bg-violet-900/10")}>
      <div ref={scrollRef} className="max-h-[400px] overflow-y-auto p-3 space-y-2.5">
        <AnimatePresence>
          {msgs.map(renderMessage)}
        </AnimatePresence>
        {streaming && (
          <div className="flex items-center gap-2 px-1">
            <MaiAvatar emotion="thinking" size="xs" />
            <div className="flex gap-1">
              {[0, 1, 2].map((i) => (
                <div key={i} className="w-1.5 h-1.5 rounded-full bg-primary/40 animate-bounce" style={{ animationDelay: `${i * 0.15}s` }} />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
});

InlineWorkFlow.displayName = "InlineWorkFlow";
export default InlineWorkFlow;
