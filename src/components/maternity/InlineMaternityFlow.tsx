import React, { useState, useEffect, useRef, forwardRef, useImperativeHandle } from "react";
import { motion, AnimatePresence } from "framer-motion";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { cn } from "@/lib/utils";
import { useBargeIn } from "@/hooks/useBargeIn";
import { activateLactationPlan, setCurrentGoal, mockPlans, planColors, refreshTodayTasks } from "@/data/planMockData";

/* ── Types ── */
interface ChatMsg {
  id: string;
  role: "mai" | "user";
  content: string;
  type?: "text" | "choice" | "plan-card" | "bag-card";
  choiceOptions?: { label: string; action: string }[];
}

export interface InlineMaternityFlowHandle {
  handleExternalInput: (text: string) => boolean;
}

interface Props {
  onComplete?: () => void;
}

/* ── Stage machine ── */
type Stage =
  | "greeting"
  | "ask-due-date"
  | "ask-delivery"
  | "ask-condition"
  | "ask-concern"
  | "assessing"
  | "result"
  | "show-bag"
  | "ask-adjust"
  | "adjust-confirm"
  | "done";

/* ── Mock bag items ── */
const bagItems = [
  { category: "妈妈用品", items: ["产褥垫 ×10", "一次性内裤 ×8", "哺乳内衣 ×3", "月子帽", "防滑拖鞋", "吸管杯"] },
  { category: "宝宝用品", items: ["新生儿衣服 ×5", "NB尿不湿 ×1包", "包被 ×2", "湿巾", "棉柔巾", "婴儿帽 ×2"] },
  { category: "证件资料", items: ["身份证", "医保卡", "母子健康手册", "产检报告", "出生证明材料"] },
  { category: "吸乳相关", items: ["Momcozy M.ai Pro 吸乳器", "储奶袋 ×30", "奶瓶 ×2", "奶瓶刷", "消毒锅"] },
];

/* ── Component ── */
const InlineMaternityFlow = forwardRef<InlineMaternityFlowHandle, Props>(({ onComplete }, ref) => {
  const [msgs, setMsgs] = useState<ChatMsg[]>([]);
  const [stage, setStage] = useState<Stage>("greeting");
  const [streaming, setStreaming] = useState(false);
  const [awaitingInput, setAwaitingInput] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const { track, interrupt } = useBargeIn();

  // Collected data
  const [dueDate, setDueDate] = useState("");
  const [delivery, setDelivery] = useState("");
  const [condition, setCondition] = useState("");
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

  // Init
  useEffect(() => {
    const greet: ChatMsg = {
      id: "greet-1",
      role: "mai",
      content: "准妈妈你好呀！🤰💕\n\n很高兴能在这个特别的时刻陪伴你。怀孕是一段充满期待和变化的旅程，Mai 会全程陪着你，帮你做好每一步准备。\n\n不用紧张，我们一起来规划，让你安心迎接宝宝的到来～",
    };
    setMsgs([greet]);
    setTimeout(() => {
      pushMai("首先，Mai 需要了解一些基本情况，方便为你制定专属的待产计划 📋\n\n你的预产期大约在什么时候呢？（例如：2026年8月、下个月等）", {
        type: "choice",
        choiceOptions: [
          { label: "2026年7月", action: "due-jul" },
          { label: "2026年8月", action: "due-aug" },
          { label: "2026年9月", action: "due-sep" },
          { label: "还不确定", action: "due-unknown" },
        ],
      });
      setStage("ask-due-date");
    }, 1200);
  }, []);

  const handleChoice = (action: string) => {
    switch (stage) {
      case "ask-due-date": {
        const labels: Record<string, string> = {
          "due-jul": "2026年7月", "due-aug": "2026年8月", "due-sep": "2026年9月", "due-unknown": "还不确定",
        };
        const label = labels[action] || action;
        setDueDate(label);
        pushUser(label);
        pushMai("收到！了解你的分娩意愿也很重要，这会影响待产准备和产后恢复计划 🏥\n\n你目前倾向于哪种分娩方式呢？", {
          type: "choice",
          choiceOptions: [
            { label: "顺产", action: "natural" },
            { label: "剖宫产", action: "cesarean" },
            { label: "还在考虑中", action: "undecided" },
          ],
        });
        setStage("ask-delivery");
        break;
      }
      case "ask-delivery": {
        const labels: Record<string, string> = { natural: "顺产", cesarean: "剖宫产", undecided: "还在考虑中" };
        setDelivery(labels[action] || action);
        pushUser(labels[action] || action);
        pushMai("好的～再了解一下你目前的身体状况，这样 Mai 可以更有针对性地为你规划 💪\n\n你现在身体状况怎么样？", {
          type: "choice",
          choiceOptions: [
            { label: "状态很好", action: "good" },
            { label: "有些疲劳", action: "tired" },
            { label: "有孕期不适", action: "discomfort" },
            { label: "有医生特别嘱咐", action: "medical" },
          ],
        });
        setStage("ask-condition");
        break;
      }
      case "ask-condition": {
        const labels: Record<string, string> = {
          good: "状态很好", tired: "有些疲劳", discomfort: "有孕期不适", medical: "有医生特别嘱咐",
        };
        setCondition(labels[action] || action);
        pushUser(labels[action] || action);

        let conditionAdvice = "";
        if (action === "tired") conditionAdvice = "疲劳是孕期常见的，注意休息和营养补充很重要。";
        else if (action === "discomfort") conditionAdvice = "孕期不适很正常，Mai 会在计划中加入缓解建议。";
        else if (action === "medical") conditionAdvice = "有医生嘱咐很好，Mai 会把这些纳入计划考量。";
        else conditionAdvice = "状态很棒！保持下去～";

        pushMai(`${conditionAdvice}\n\n最后一个问题：你目前最关心或担心的是什么呢？ 🤔`, {
          type: "choice",
          choiceOptions: [
            { label: "产后母乳喂养", action: "breastfeeding" },
            { label: "分娩过程", action: "labor" },
            { label: "产后恢复", action: "recovery" },
            { label: "新生儿护理", action: "newborn" },
          ],
        });
        setStage("ask-concern");
        break;
      }
      case "ask-concern": {
        const labels: Record<string, string> = {
          breastfeeding: "产后母乳喂养", labor: "分娩过程", recovery: "产后恢复", newborn: "新生儿护理",
        };
        setConcern(labels[action] || action);
        pushUser(labels[action] || action);
        setStage("assessing");

        // Simulate assessment
        pushMai("收到所有信息！Mai 正在为你生成专属待产计划，请稍等... ⏳");
        setTimeout(() => {
          // Show plan card
          const planData = mockPlans.find((p) => p.id === "fertility");
          pushMsg({
            id: `plan-card-${Date.now()}`,
            role: "mai",
            content: "",
            type: "plan-card",
          });
          setTimeout(() => {
            pushMai("这是 Mai 根据你的情况准备的待产包清单，提前准备好可以让你更安心 🎒✨");
            setTimeout(() => {
              pushMsg({
                id: `bag-card-${Date.now()}`,
                role: "mai",
                content: "",
                type: "bag-card",
              });
              setTimeout(() => {
                pushMai("以上就是你的专属待产方案！ 🌟\n\n你觉得这个计划安排怎么样？需要调整吗？", {
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
          pushMai("太好了！待产计划已启用并同步到你的呵护计划中 🎉\n\n你可以在日程页面的「今日」「Milestone」和「月历」中查看完整计划安排。\n\nMai 会全程陪伴你，有任何变化随时来找我聊聊哦～加油准妈妈！💪🤰", {
            type: "choice",
            choiceOptions: [{ label: "去查看呵护计划", action: "go-schedule" }],
          });
          setStage("done");
        } else {
          pushUser("需要调整一下");
          setAwaitingInput(true);
          pushMai("没问题！请告诉我你想调整的部分，比如：\n\n• 调整某个阶段的时间安排\n• 增加或减少某些待产准备项\n• 修改分娩方式相关的准备\n\n随意说，Mai 来帮你优化～ 💕");
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

  const handleTextInput = (text: string) => {
    if (stage === "adjust-confirm") {
      pushUser(text);
      setAwaitingInput(false);
      setTimeout(() => {
        pushMai(`好的，已根据你的反馈「${text}」调整了待产计划 ✅\n\n调整后的计划会更符合你的实际情况。确认启用调整后的方案吗？`, {
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

  // Handle "confirm-adjusted" as accept
  const handleChoiceWrapper = (action: string) => {
    if (action === "confirm-adjusted") {
      pushUser("确认启用");
      syncPlanToSchedule();
      pushMai("调整后的待产计划已启用 🎉\n\n已同步到呵护计划的今日任务、Milestone 和月历中。\n\nMai 随时在这里陪伴你，祝一切顺利！💕🤰", {
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

  const syncPlanToSchedule = () => {
    activateLactationPlan("fertility");
    setCurrentGoal({
      planId: "fertility",
      label: "待产计划",
      summary: `预产期${dueDate || "待确认"}，${delivery || "分娩方式待定"} 🤰`,
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
    const plan = mockPlans.find((p) => p.id === "fertility");
    const colors = planColors.fertility;
    if (!plan) return null;

    return (
      <div className={cn("rounded-xl border p-3 space-y-2", colors.bg, colors.border)}>
        <div className="flex items-center gap-2">
          <span className="text-lg">{plan.emoji}</span>
          <div>
            <p className={cn("text-[13px] font-bold", colors.text)}>专属待产计划</p>
            <p className="text-[10px] text-muted-foreground">
              预产期 {dueDate || "待确认"} · {delivery || "分娩方式待定"}
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

  const renderBagCard = () => (
    <div className="rounded-xl border border-amber-300 dark:border-amber-700 bg-amber-50 dark:bg-amber-900/20 p-3 space-y-2">
      <div className="flex items-center gap-2">
        <span className="text-lg">🎒</span>
        <p className="text-[13px] font-bold text-amber-800 dark:text-amber-200">待产包清单</p>
      </div>
      <div className="grid grid-cols-2 gap-2">
        {bagItems.map((cat) => (
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
    if (msg.type === "bag-card") {
      return (
        <motion.div key={msg.id} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="w-full">
          {renderBagCard()}
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
        {isMai && <MaiAvatar emotion="happy" size="xs" className="mt-1 shrink-0" />}
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
    <div className="rounded-2xl border border-pink-200 dark:border-pink-800 bg-pink-50/50 dark:bg-pink-900/10 overflow-hidden">
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

InlineMaternityFlow.displayName = "InlineMaternityFlow";
export default InlineMaternityFlow;
