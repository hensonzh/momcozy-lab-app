import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";

interface Props {
  open: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

const ReminderAlert: React.FC<Props> = ({ open, onConfirm, onCancel }) => (
  <AnimatePresence>
    {open && (
      <>
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[60] bg-foreground/30 backdrop-blur-sm"
          onClick={onCancel}
        />
        {/* 用 flex 居中：避免 motion 的 transform(scale) 覆盖 Tailwind 的 translate 导致偏位 */}
        <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 pointer-events-none">
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          className="pointer-events-auto w-[85vw] max-w-sm bg-card border border-border rounded-2xl p-5 shadow-2xl"
        >
          <div className="flex items-center gap-2 mb-3">
            <AlertTriangle className="w-5 h-5 text-mai-warm" />
            <h4 className="text-base font-bold text-foreground">关闭提醒？</h4>
          </div>
          <p className="text-sm text-muted-foreground mb-5 leading-relaxed">
            关闭后，将停止<strong className="text-foreground">系统级后台提醒</strong>（含锁屏/全屏提醒与悬浮窗相关能力），Mai
            也无法再为你提供<strong className="text-foreground">个性化排期优化</strong>与<strong className="text-foreground">智能防冲突</strong>。确定要关闭吗？
          </p>
          <div className="flex gap-3">
            <Button variant="outline" onClick={onCancel} className="flex-1 rounded-xl">保持开启</Button>
            <Button variant="destructive" onClick={onConfirm} className="flex-1 rounded-xl">仍要关闭</Button>
          </div>
        </motion.div>
        </div>
      </>
    )}
  </AnimatePresence>
);

export default ReminderAlert;
