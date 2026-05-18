import React, { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, CheckCircle2, Loader2 } from "lucide-react";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { mockPlans, getCurrentGoal, setCurrentGoal, activateLactationPlan, LACTATION_PLAN_IDS } from "@/data/planMockData";
import { cn } from "@/lib/utils";

interface Props {
  open: boolean;
  onClose: () => void;
  onAskMai: () => void;
  onStartWorkPlan?: () => void;
}

const LactationGoalSheet: React.FC<Props> = ({
  open,
  onClose,
  onAskMai: _onAskMai,
  onStartWorkPlan: _onStartWorkPlan,
}) => {
  const currentGoal = getCurrentGoal();
  const [selectedPlanId, setSelectedPlanId] = useState(currentGoal.planId);
  const [isApplying, setIsApplying] = useState(false);

  useEffect(() => {
    if (open) {
      setSelectedPlanId(getCurrentGoal().planId);
      setIsApplying(false);
    }
  }, [open]);

  const lactationPlans = mockPlans.filter((p) => (LACTATION_PLAN_IDS as readonly string[]).includes(p.id));

  const recommendedPlanId = "chase";

  const handleConfirm = () => {
    if (selectedPlanId === currentGoal.planId) {
      onClose();
      return;
    }

    setIsApplying(true);
    setTimeout(() => {
      const plan = lactationPlans.find((p) => p.id === selectedPlanId);
      if (plan) {
        activateLactationPlan(selectedPlanId);
        setCurrentGoal({ planId: selectedPlanId, label: plan.name, summary: plan.maiSummary });
      }
      setIsApplying(false);
      onClose();
    }, 800);
  };

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-foreground/30 backdrop-blur-sm"
            onClick={() => !isApplying && onClose()}
          />
          <motion.div
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", damping: 28, stiffness: 300 }}
            drag="y"
            dragConstraints={{ top: 0 }}
            dragElastic={0.2}
            onDragEnd={(_e, { offset, velocity }) => {
              if (offset.y > 100 || velocity.y > 500) {
                if (!isApplying) onClose();
              }
            }}
            className="fixed inset-x-0 bottom-0 z-50 w-full max-w-lg mx-auto max-h-[85vh] rounded-t-[32px] bg-card shadow-2xl flex flex-col"
          >
            <div className="flex justify-center pt-3 pb-2 flex-shrink-0 cursor-grab active:cursor-grabbing">
              <div className="w-12 h-1.5 rounded-full bg-border" />
            </div>

            <div className="flex items-center justify-between px-5 pb-3 flex-shrink-0">
              <h3 className="text-[18px] font-extrabold text-foreground flex items-center gap-1.5">
                ✨ 智能目标评估
              </h3>
              <button
                type="button"
                onClick={() => !isApplying && onClose()}
                className="p-1.5 rounded-full hover:bg-secondary active:scale-90 transition-all"
              >
                <X className="w-5 h-5 text-muted-foreground" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto px-5 pb-6">
              <div className="flex gap-3 mb-6 bg-gradient-to-br from-primary/10 to-primary/5 rounded-[24px] rounded-tl-sm p-4 border border-primary/10">
                <MaiAvatar emotion="encourage" size="md" animate className="shrink-0 drop-shadow-sm mt-1" />
                <div className="text-[14px] text-foreground leading-relaxed">
                  <p>
                    根据宝宝最近的体重推算，每天大约需要 <strong>800ml</strong>，而你近三天日均产出为 <strong>650ml</strong>。
                  </p>
                  <p className="mt-2 text-primary font-bold">
                    为了避免后续口粮紧张，建议将目标调整为「安心追奶」，我来帮你重新安排更密集的排期吧？
                  </p>
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-[13px] font-bold text-muted-foreground ml-1">请选择今日目标</span>
                </div>

                {lactationPlans.map((plan) => {
                  const isSelected = selectedPlanId === plan.id;
                  const isRecommended = plan.id === recommendedPlanId;

                  return (
                    <button
                      key={plan.id}
                      type="button"
                      onClick={() => setSelectedPlanId(plan.id)}
                      className={cn(
                        "w-full flex items-center p-4 rounded-2xl border-2 transition-all text-left relative overflow-hidden active:scale-[0.98]",
                        isSelected
                          ? "border-primary bg-primary/5 shadow-sm"
                          : "border-border/50 bg-background hover:bg-secondary/40 hover:border-border"
                      )}
                    >
                      <div
                        className={cn(
                          "w-6 h-6 rounded-full border-2 flex items-center justify-center shrink-0 mr-3 transition-colors",
                          isSelected ? "border-primary bg-primary" : "border-muted-foreground/30"
                        )}
                      >
                        {isSelected && <CheckCircle2 className="w-4 h-4 text-primary-foreground" />}
                      </div>

                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <span className="text-xl leading-none">{plan.emoji}</span>
                          <span className={cn("text-[16px] font-bold", isSelected ? "text-foreground" : "text-muted-foreground")}>
                            {plan.name}
                          </span>
                          {isRecommended && (
                            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-destructive text-destructive-foreground animate-pulse">
                              M.ai 推荐
                            </span>
                          )}
                        </div>
                        <p className="text-[12px] text-muted-foreground mt-1 line-clamp-2 pr-4">{plan.maiSummary}</p>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>

            <div
              className="px-4 pt-3 bg-card border-t border-border/50 flex-shrink-0"
              style={{ paddingBottom: "max(1rem, env(safe-area-inset-bottom))" }}
            >
              <button
                type="button"
                disabled={isApplying}
                onClick={handleConfirm}
                className="w-full h-14 bg-foreground text-background rounded-[20px] text-base font-bold shadow-md shadow-foreground/10 active:scale-[0.98] transition-transform flex items-center justify-center gap-2 disabled:opacity-80 disabled:scale-100"
              >
                {isApplying ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin" />
                    正在为你重新排期...
                  </>
                ) : selectedPlanId === currentGoal.planId ? (
                  "保持当前目标"
                ) : (
                  "确定并让 M.ai 重新排期"
                )}
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default LactationGoalSheet;
