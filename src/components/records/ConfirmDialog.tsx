import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Button } from "@/components/ui/button";

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: string;
  onConfirm: () => void;
  onCancel: () => void;
  confirmLabel?: string;
  destructive?: boolean;
}

const ConfirmDialog: React.FC<ConfirmDialogProps> = ({
  open, title, description, onConfirm, onCancel, confirmLabel = "确认", destructive = false,
}) => (
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
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          className="fixed z-[60] left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-[80vw] max-w-sm bg-card border border-border rounded-2xl p-5 shadow-2xl"
        >
          <h4 className="text-base font-bold text-foreground mb-2">{title}</h4>
          <p className="text-sm text-muted-foreground mb-5">{description}</p>
          <div className="flex gap-3">
            <Button variant="outline" onClick={onCancel} className="flex-1 rounded-xl">取消</Button>
            <Button
              onClick={onConfirm}
              className="flex-1 rounded-xl"
              variant={destructive ? "destructive" : "default"}
            >
              {confirmLabel}
            </Button>
          </div>
        </motion.div>
      </>
    )}
  </AnimatePresence>
);

export default ConfirmDialog;
