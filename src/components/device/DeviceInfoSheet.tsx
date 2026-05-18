import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X } from "lucide-react";
import type { DeviceInfo } from "@/data/mockData";

interface Props {
  device: DeviceInfo | null;
  open: boolean;
  onClose: () => void;
  onOpenDebug?: (device: DeviceInfo) => void;
}

const DeviceInfoSheet: React.FC<Props> = ({ device, open, onClose, onOpenDebug }) => {
  if (!device) return null;

  const sideLabel = device.side === "L" ? "左侧主机" : "右侧主机";

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-foreground/20 backdrop-blur-sm"
            onClick={onClose}
          />
          <motion.div
            initial={{ opacity: 0, y: "100%" }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: "100%" }}
            transition={{ type: "spring", damping: 28, stiffness: 300 }}
            className="fixed inset-x-0 bottom-0 z-50 flex max-h-[85vh] flex-col rounded-t-3xl border-t border-border bg-card shadow-2xl"
          >
            <div className="flex items-center justify-between border-b border-border/50 px-5 pb-3 pt-4">
              <div>
                <h2 className="text-base font-bold text-foreground">{device.model}</h2>
                <p className="text-[11px] text-muted-foreground">{sideLabel}</p>
              </div>
              <button
                onClick={onClose}
                className="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-muted-foreground transition-colors hover:text-foreground"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="flex-1 space-y-5 overflow-y-auto px-5 pb-8 pt-4">
              <section className="space-y-2">
                <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">设备信息</span>
                <div className="grid grid-cols-2 gap-2">
                  {[
                    { label: "蓝牙名称", value: device.model },
                    { label: "固件版本", value: device.firmware },
                    { label: "序列号", value: device.serialNumber },
                  ].map((item) => (
                    <div key={item.label} className="rounded-xl bg-secondary/50 p-3">
                      <p className="text-[10px] font-medium text-muted-foreground">{item.label}</p>
                      <p className="mt-0.5 text-sm font-bold text-foreground">{item.value}</p>
                    </div>
                  ))}
                </div>
                {device.connected ? (
                  <button
                    type="button"
                    onClick={() => onOpenDebug?.(device)}
                    className="mt-3 h-11 w-full rounded-xl bg-primary text-sm font-semibold text-primary-foreground shadow-[0_10px_24px_hsl(var(--mai-glow)/0.18)] transition hover:bg-primary/90"
                  >
                    设备调试
                  </button>
                ) : null}
              </section>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default DeviceInfoSheet;
