import React, { useState, useEffect, useRef, forwardRef, useImperativeHandle } from "react";
import { motion, AnimatePresence } from "framer-motion";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { cn } from "@/lib/utils";
import { useBargeIn } from "@/hooks/useBargeIn";
import { dailySummary } from "@/data/mockData";
import { activateLactationPlan, setCurrentGoal, mockPlans, planColors, getCurrentGoal, refreshTodayTasks } from "@/data/planMockData";

/* ── Types ── */
interface ChatMsg {
  id: string;
  role: "mai" | "user";
  content: string;
  type?: "text" | "choice" | "phase-card" | "trend-card" | "plan-card";
  choiceOptions?: { label: string; action: string }[];
}

export interface InlineLactationFlowHandle {
  handleExternalInput: (text: string) => boolean;
}

interface Props {
  onComplete?: () => void;
  initialAction?: string;
  assessContext?: { totalAvailable: number; feedP50: number; bfCount: number; bfTotalMin: number; babyName: string };
}

/* ── Data ── */
const milkyPhases = [
  { key: "colostrum", label: "初乳期", detail: "0-3天", active: false },
  { key: "establish", label: "建立期", detail: "1-4周", active: false },
  { key: "stable", label: "稳产期", detail: "1-6月 ✅ 当前", active: true },
  { key: "weaning", label: "离乳期", detail: "6月+", active: false },
];

const avg = Math.round(dailySummary.reduce((s, d) => s + d.total, 0) / dailySummary.length);

type Stage =
  | "init"
  | "ask-direction"
  | "ask-reason"
  | "ask-concern"
  | "assessing"
  | "show-plan"
  | "ask-adjust"
  | "adjust-input"
  | "done";

type Direction = "increase" | "maintain" | "decrease";

const directionLabels: Record<Direction, string> = {
  increase: "安心追奶",
  maintain: "维持奶量",
  decrease: "稳步减奶",
};

const directionPlanIds: Record<Direction, string> = {
  increase: "chase",
  maintain: "maintain",
  decrease: "wean",
};

/* ── Component ── */
const InlineLactationFlow = forwardRef<InlineLactationFlowHandle, Props>(({ onComplete, initialAction, assessContext }, ref) => {
  const [msgs, setMsgs] = useState<ChatMsg[]>([]);
  const [streaming, setStreaming] = useState(false);
  const [stage, setStage] = useState<Stage>("init");
  const [direction, setDirection] = useState<Direction>("maintain");
  const [reason, setReason] = useState("");
  const [concern, setConcern] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);
  const { track, interrupt } = useBargeIn();

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

  // Init greeting
  useEffect(() => {
    const currentGoal = getCurrentGoal();
    const greeting: ChatMsg = {
      id: "greet-1",
      role: "mai",
      content: `来聊聊你的泌乳计划吧～ 🌟\n\n📌 当前阶段：稳产期（产后12周）\n🎯 当前目标：${currentGoal.label}\n📈 7日均奶量：${avg}ml/天\n\n了解你目前的情况后，Mai 可以为你制定最适合的计划方案。`,
    };
    setMsgs([greeting]);

    if (initialAction === "growth-assess" && assessContext) {
      setTimeout(() => handleChoice("growth-assess"), 300);
    } else {
      setTimeout(() => {
        pushMai("你现在对奶量有什么想法呢？ 💭", {
          type: "choice",
          choiceOptions: [
            { label: "💪 我想增加奶量", action: "dir-increase" },
            { label: "👌 维持奶量稳定", action: "dir-maintain" },
            { label: "🌸 准备逐步减量", action: "dir-decrease" },
          ],
        });
        setStage("ask-direction");
      }, 1000);
    }
  }, []);

  useImperativeHandle(ref, () => ({
    handleExternalInput: (text: string) => {
      if (streaming) {
        interrupt();
        setStreaming(false);
        setMsgs(prev => [...prev, { id: `int-${Date.now()}`, role: "mai", content: "── 用户打断输出 ──" }]);
      }
      if (stage === "adjust-input") {
        handleTextInput(text);
        return true;
      }
      return false;
    },
  }));

  const handleTextInput = (text: string) => {
    if (stage === "adjust-input") {
      pushUser(text);
      setStage("show-plan");
      setTimeout(() => {
        pushMai(`好的，已根据你的反馈「${text}」调整了${directionLabels[direction]}计划 ✅\n\n确认启用调整后的方案吗？`, {
          type: "choice",
          choiceOptions: [
            { label: "✅ 确认启用", action: "confirm-adjusted" },
            { label: "🤔 再想想", action: "reconsider" },
          ],
        });
      }, 800);
      return;
    }
  };

  const syncPlanToSchedule = () => {
    const planId = directionPlanIds[direction];
    activateLactationPlan(planId);
    const summaryMap: Record<Direction, string> = {
      increase: `追奶模式，目标提升至日均${avg + 100}ml 💪`,
      maintain: `稳定维持日均${avg}ml，按需微调 👌`,
      decrease: `温和减量，逐步降至日均${Math.max(avg - 150, 200)}ml 🌸`,
    };
    setCurrentGoal({
      planId,
      label: directionLabels[direction],
      summary: summaryMap[direction],
    });

    // Also inject tasks for chase/wean
    if (direction === "increase") {
      const chaseTasks = [
        { id: `chase-${Date.now()}-1`, time: "05:00", type: "pump" as const, title: "🌙 凌晨追奶排空", done: false, adjusted: "M.ai计划新增", source: "mai" as const, reason: "追奶计划" },
        { id: `chase-${Date.now()}-2`, time: "16:00", type: "pump" as const, title: "☀️ 下午加排", done: false, adjusted: "M.ai计划新增", source: "mai" as const, reason: "追奶计划" },
      ];
      const existing = JSON.parse(localStorage.getItem("chaseMilkTasks") || "[]");
      localStorage.setItem("chaseMilkTasks", JSON.stringify([...existing, ...chaseTasks]));
      window.dispatchEvent(new Event("chaseMilkUpdated"));
    } else if (direction === "decrease") {
      const reduceTasks = [
        { id: `reduce-${Date.now()}`, time: "14:00", type: "pump" as const, title: "🌸 减量：跳过此次排空", done: true, adjusted: "M.ai计划调整", source: "mai" as const, reason: "舒适减奶" },
      ];
      const existing = JSON.parse(localStorage.getItem("chaseMilkTasks") || "[]");
      localStorage.setItem("chaseMilkTasks", JSON.stringify([...existing, ...reduceTasks]));
      window.dispatchEvent(new Event("chaseMilkUpdated"));
    }
    // Refresh today tasks from updated plans
    refreshTodayTasks();
  };

  const handleChoice = (action: string) => {
    switch (action) {
      // ── Direction selection ──
      case "dir-increase":
      case "dir-maintain":
      case "dir-decrease": {
        const dir = action.replace("dir-", "") as Direction;
        setDirection(dir);
        pushUser(directionLabels[dir]);

        const reasonPrompts: Record<Direction, { msg: string; options: { label: string; action: string }[] }> = {
          increase: {
            msg: "了解！想追奶是个很积极的决定 💪\n\n可以告诉我是什么原因想追奶呢？这样我能更有针对性地为你规划。",
            options: [
              { label: "宝宝需求增加了", action: "reason-demand" },
              { label: "想储备更多母乳", action: "reason-stock" },
              { label: "奶量最近下降了", action: "reason-drop" },
            ],
          },
          maintain: {
            msg: `很好的选择！目前日均${avg}ml 非常稳定 👍\n\n维持产量也需要科学管理，了解一下你的情况：`,
            options: [
              { label: "目前节奏很好", action: "reason-good" },
              { label: "偶尔会有波动", action: "reason-fluctuate" },
              { label: "担心会减少", action: "reason-worry" },
            ],
          },
          decrease: {
            msg: "理解你的决定，减奶是一个温柔的过程 🌸\n\n可以聊聊减奶的原因吗？",
            options: [
              { label: "宝宝开始吃辅食了", action: "reason-solid" },
              { label: "身体比较疲劳", action: "reason-tired" },
              { label: "准备回归工作", action: "reason-work" },
            ],
          },
        };

        const prompt = reasonPrompts[dir];
        pushMai(prompt.msg, { type: "choice", choiceOptions: prompt.options });
        setStage("ask-reason");
        break;
      }

      // ── Reason collection ──
      case "reason-demand":
      case "reason-stock":
      case "reason-drop":
      case "reason-good":
      case "reason-fluctuate":
      case "reason-worry":
      case "reason-solid":
      case "reason-tired":
      case "reason-work": {
        const reasonLabels: Record<string, string> = {
          "reason-demand": "宝宝需求增加了",
          "reason-stock": "想储备更多母乳",
          "reason-drop": "奶量最近下降了",
          "reason-good": "目前节奏很好",
          "reason-fluctuate": "偶尔会有波动",
          "reason-worry": "担心会减少",
          "reason-solid": "宝宝开始吃辅食了",
          "reason-tired": "身体比较疲劳",
          "reason-work": "准备回归工作",
        };
        setReason(reasonLabels[action] || action);
        pushUser(reasonLabels[action] || action);

        const concernPrompts: Record<Direction, string> = {
          increase: "收到！追奶过程中你最关心的是什么？ 🤔",
          maintain: "好的～维持稳定期间你最在意什么呢？ 🤔",
          decrease: "明白了～减奶过程中你最担心什么？ 🤔",
        };

        const concernOptions: Record<Direction, { label: string; action: string }[]> = {
          increase: [
            { label: "怕影响休息", action: "concern-rest" },
            { label: "怕堵奶", action: "concern-block" },
            { label: "效果多久见效", action: "concern-time" },
          ],
          maintain: [
            { label: "夜奶太累", action: "concern-night" },
            { label: "出行不方便", action: "concern-travel" },
            { label: "没有特别担心", action: "concern-none" },
          ],
          decrease: [
            { label: "怕涨奶不适", action: "concern-engorgement" },
            { label: "担心宝宝不够吃", action: "concern-baby" },
            { label: "心理上不舍得", action: "concern-emotion" },
          ],
        };

        pushMai(concernPrompts[direction], {
          type: "choice",
          choiceOptions: concernOptions[direction],
        });
        setStage("ask-concern");
        break;
      }

      // ── Concern collection → Assessment ──
      case "concern-rest":
      case "concern-block":
      case "concern-time":
      case "concern-night":
      case "concern-travel":
      case "concern-none":
      case "concern-engorgement":
      case "concern-baby":
      case "concern-emotion": {
        const concernLabels: Record<string, string> = {
          "concern-rest": "怕影响休息",
          "concern-block": "怕堵奶",
          "concern-time": "效果多久见效",
          "concern-night": "夜奶太累",
          "concern-travel": "出行不方便",
          "concern-none": "没有特别担心",
          "concern-engorgement": "怕涨奶不适",
          "concern-baby": "担心宝宝不够吃",
          "concern-emotion": "心理上不舍得",
        };
        setConcern(concernLabels[action] || action);
        pushUser(concernLabels[action] || action);
        setStage("assessing");

        // Assessment
        pushMai("收到所有信息！Mai 正在为你生成专属计划，请稍等... ⏳");
        setTimeout(() => {
          // Show plan card
          pushMsg({
            id: `plan-card-${Date.now()}`,
            role: "mai",
            content: "",
            type: "plan-card",
          });
          setTimeout(() => {
            const planName = directionLabels[direction];
            pushMai(`以上就是你的专属「${planName}」方案！ 🌟\n\n这个计划会同步到呵护计划的今日任务、Milestone 和月历中。\n\n你觉得这个安排怎么样？`, {
              type: "choice",
              choiceOptions: [
                { label: "很好，直接启用", action: "accept" },
                { label: "需要调整一下", action: "adjust" },
              ],
            });
            setStage("show-plan");
          }, 800);
        }, 1500);
        break;
      }

      // ── Plan acceptance ──
      case "accept":
      case "confirm-adjusted": {
        pushUser(action === "accept" ? "很好，直接启用" : "确认启用");
        syncPlanToSchedule();
        const planName = directionLabels[direction];
        pushMai(`太好了！「${planName}」计划已启用并同步到呵护计划中 🎉\n\n📅 今日任务已更新\n📊 Milestone 里程碑已刷新\n🗓️ 月历排期已同步\n\nMai 会全程陪伴你，有任何变化随时来找我聊聊哦～加油！💕`, {
          type: "choice",
          choiceOptions: [{ label: "📅 去查看呵护计划", action: "go-schedule" }],
        });
        setStage("done");
        break;
      }
      case "adjust": {
        pushUser("需要调整一下");
        pushMai("没问题！请告诉我你想调整的部分，比如：\n\n• 调整排空频率或时间\n• 增减某些任务\n• 修改阶段时长\n\n随意说，Mai 来帮你优化～ 💕");
        setStage("adjust-input");
        break;
      }
      case "reconsider": {
        pushUser("再想想");
        pushMai("没关系，慢慢来～你随时可以回来继续规划。\n\n有任何想法都可以告诉 Mai 哦 💕");
        setStage("done");
        onComplete?.();
        break;
      }
      case "go-schedule": {
        pushUser("去查看呵护计划");
        window.dispatchEvent(new CustomEvent("navigate-to", { detail: "/schedule" }));
        onComplete?.();
        break;
      }

      /* ═══ Growth-triggered assessment flow (preserved) ═══ */
      case "growth-assess": {
        const ctx = assessContext;
        const supplyRatio = ctx && ctx.feedP50 > 0 ? ctx.totalAvailable / ctx.feedP50 : 1;
        const supplyPct = Math.round(supplyRatio * 100);
        const babyName = ctx?.babyName || "宝宝";
        const bfNote = ctx && ctx.bfCount > 0
          ? `\n\n💡 不过你今天有 ${ctx.bfCount} 次亲喂（共${ctx.bfTotalMin}分钟），亲喂的奶量很难精确计算，实际摄入可能比记录的多不少。`
          : "";

        pushMai(
          `📋 先帮你梳理一下今天的情况：\n\n` +
          `• 记录可用乳源：${ctx?.totalAvailable || 0}ml\n` +
          `• ${babyName}每日参考需求：${ctx?.feedP50 || 0}ml\n` +
          `• 当前供需比：约 ${supplyPct}%` +
          bfNote +
          `\n\n别着急下结论，我们先确认一下记录是否完整 ☺️`,
          {
            type: "choice",
            choiceOptions: [
              { label: "📝 有漏记的奶量", action: "assess-has-missing" },
              { label: "✅ 记录都齐了", action: "assess-complete" },
            ],
          }
        );
        break;
      }
      case "assess-has-missing": {
        pushUser("有漏记的奶量");
        pushMai(
          "没关系，很多妈妈都会有漏记的情况～\n\n建议你去「妈妈点滴」补录一下，然后回来看看数据有没有变化 😊",
          {
            type: "choice",
            choiceOptions: [
              { label: "👌 好的，先去补录", action: "done-quiet" },
              { label: "➡️ 不补了，继续", action: "assess-complete" },
            ],
          }
        );
        break;
      }
      case "assess-complete": {
        pushUser("记录都齐了");
        const ctx2 = assessContext;
        const ratio2 = ctx2 && ctx2.feedP50 > 0 ? ctx2.totalAvailable / ctx2.feedP50 : 1;

        if (ratio2 < 0.85) {
          pushMai(
            "综合来看，记录的奶量确实偏少一些。\n\n妈妈辛苦了 💕 Mai 可以为你制定一个温和的追奶方案，要试试吗？",
            {
              type: "choice",
              choiceOptions: [
                { label: "💪 好的，帮我追奶", action: "dir-increase" },
                { label: "😌 感觉够吃的", action: "dir-maintain" },
              ],
            }
          );
        } else if (ratio2 > 1.3) {
          pushMai(
            `产量很充裕 🎉 如果觉得累，可以考虑适当调整。\n\n你想怎么做呢？`,
            {
              type: "choice",
              choiceOptions: [
                { label: "👌 维持现状", action: "dir-maintain" },
                { label: "🌸 适当减量", action: "dir-decrease" },
              ],
            }
          );
        } else {
          pushMai(
            "奶量和需求基本匹配，很棒！ ✨\n\n你对目前状态满意吗？",
            {
              type: "choice",
              choiceOptions: [
                { label: "👌 维持稳定", action: "dir-maintain" },
                { label: "💪 想再多一些", action: "dir-increase" },
                { label: "🌸 想轻松一些", action: "dir-decrease" },
              ],
            }
          );
        }
        break;
      }
      case "done-quiet": {
        pushUser("好的，先去补录");
        onComplete?.();
        break;
      }

      default:
        break;
    }
  };

  /* ── Render helpers ── */
  const renderPlanCard = () => {
    const planId = directionPlanIds[direction];
    const plan = mockPlans.find((p) => p.id === planId);
    const colors = planColors[planId];
    if (!plan) return null;

    const riskMap: Record<Direction, string> = {
      increase: "⚠️ 追奶初期可能疲劳，注意休息和水分补充",
      maintain: "💡 保持规律作息，避免突然改变频率",
      decrease: "⚠️ 减量过快可能涨奶，出现硬块请暂停",
    };

    return (
      <div className={cn("rounded-xl border p-3 space-y-2.5", colors.bg, colors.border)}>
        <div className="flex items-center gap-2">
          <span className="text-lg">{plan.emoji}</span>
          <div>
            <p className={cn("text-[13px] font-bold", colors.text)}>专属{directionLabels[direction]}计划</p>
            <p className="text-[10px] text-muted-foreground">
              基于日均{avg}ml · {reason || "综合评估"}
            </p>
          </div>
        </div>

        {/* Risk note */}
        <div className="px-2 py-1.5 rounded-lg bg-background/60 text-[10px] text-foreground/70">
          {riskMap[direction]}
        </div>

        {/* Milestones */}
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

  const renderPhaseCard = () => (
    <div className="flex items-center gap-0.5 mt-2">
      {milkyPhases.map((phase) => (
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

  const renderTrendCard = () => {
    const max = Math.max(...dailySummary.map((d) => d.total));
    return (
      <div className="mt-2 space-y-1">
        {dailySummary.map((d) => (
          <div key={d.date} className="flex items-center gap-2 text-[11px]">
            <span className="font-mono text-muted-foreground w-10 shrink-0">{d.date}</span>
            <div className="flex-1 h-3 bg-secondary/40 rounded-full overflow-hidden">
              <div className="h-full bg-primary/60 rounded-full transition-all" style={{ width: `${(d.total / max) * 100}%` }} />
            </div>
            <span className="font-bold text-foreground w-12 text-right">{d.total}ml</span>
          </div>
        ))}
        <div className="flex items-center justify-center gap-1 pt-1 text-[10px] text-muted-foreground">
          <span>日均 {avg}ml</span>
          <span>·</span>
          <span>{dailySummary.reduce((s, d) => s + d.sessions, 0)} 次排空</span>
        </div>
      </div>
    );
  };

  const renderMessage = (msg: ChatMsg) => {
    if (msg.type === "plan-card") {
      return (
        <motion.div key={msg.id} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="w-full">
          {renderPlanCard()}
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
            {msg.type === "phase-card" && renderPhaseCard()}
            {msg.type === "trend-card" && renderTrendCard()}
          </div>
          {msg.choiceOptions && msg.choiceOptions.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {msg.choiceOptions.map((opt) => (
                <button
                  key={opt.action}
                  onClick={() => handleChoice(opt.action)}
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
    <div className="w-full space-y-2.5">
      <div ref={scrollRef} className="space-y-2.5">
        <AnimatePresence mode="popLayout">
          {msgs.map(renderMessage)}
        </AnimatePresence>
      </div>

      {streaming && (
        <div className="flex gap-2 items-start">
          <MaiAvatar emotion="thinking" size="xs" />
          <div className="flex gap-1">
            {[0, 1, 2].map((i) => (
              <div key={i} className="w-1.5 h-1.5 rounded-full bg-primary/40 animate-bounce" style={{ animationDelay: `${i * 0.15}s` }} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
});

InlineLactationFlow.displayName = "InlineLactationFlow";
export default InlineLactationFlow;
