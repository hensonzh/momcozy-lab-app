import React from "react";
import { X } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import type { KnowledgeCardData } from "@/data/deviceMockData";

interface Props {
  data: KnowledgeCardData | null;
  open: boolean;
  onClose: () => void;
  onAskMaiMeasure?: () => void;
}

const KnowledgeCardSheet: React.FC<Props> = ({ data, open, onClose, onAskMaiMeasure }) => {
  const isFlange = data?.title?.includes("法兰");
  if (!data) return null;

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-foreground/20 backdrop-blur-sm"
            onClick={onClose}
          />
          {/* Card */}
          <motion.div
            initial={{ opacity: 0, y: 40, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 40, scale: 0.95 }}
            transition={{ type: "spring", damping: 25, stiffness: 300 }}
            className="fixed inset-x-4 bottom-24 z-50 max-h-[70vh] overflow-y-auto rounded-3xl bg-card border border-border shadow-2xl"
          >
            {/* Header */}
            <div className="sticky top-0 bg-card/95 backdrop-blur-md px-5 pt-5 pb-3 flex items-center justify-between border-b border-border/50">
              <div className="flex items-center gap-2.5">
                <span className="text-2xl">{data.icon}</span>
                <h3 className="text-sm font-bold text-foreground">{data.title}</h3>
              </div>
              <button
                onClick={onClose}
                className="w-7 h-7 rounded-full bg-secondary flex items-center justify-center text-muted-foreground hover:text-foreground transition-colors"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            {/* Sections */}
            <div className="px-5 py-4 space-y-4">
              {data.sections.map((s, i) => (
                <motion.div
                  key={i}
                  initial={{ opacity: 0, x: -12 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: i * 0.08 }}
                  className="space-y-1.5"
                >
                  <p className="text-xs font-bold text-foreground">{s.heading}</p>
                  <p className="text-[12px] leading-relaxed text-muted-foreground">{s.content}</p>
                </motion.div>
              ))}

              {data.tip && (
                <motion.div
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ delay: 0.3 }}
                  className="rounded-2xl bg-primary/5 border border-primary/15 p-3.5"
                >
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-[12px] text-primary font-medium flex-1">
                      💡 {data.tip}
                    </p>
                    {isFlange && onAskMaiMeasure && (
                      <button
                        onClick={() => { onClose(); onAskMaiMeasure(); }}
                        className="flex-shrink-0 text-[11px] font-semibold text-primary hover:text-primary/80 transition-colors whitespace-nowrap"
                      >
                        让Mai教你正确测量 →
                      </button>
                    )}
                  </div>
                </motion.div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default KnowledgeCardSheet;
