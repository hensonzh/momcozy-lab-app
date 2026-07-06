import React, { useState, useEffect, useRef, useImperativeHandle } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Plus, Loader2, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import TimeWheelPickerSheet from "@/components/schedule/TimeWheelPickerSheet";
import { uploadFile } from "@/lib/agentApi";
import { appendQueryParams, resolveHttpRequestUrl } from "@/lib/http";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";

type TaskType = "pump" | "feed" | "custom";
type TaskData = { id: string; type: TaskType; title: string; time: string };
type VisionEventType = "pump" | "breastfeed" | "custom";

type VisionTaskEvent = {
  type: "event";
  time: string;
  event: string;
  event_type: VisionEventType;
};

type VisionDoneEvent = {
  type: "done";
  count?: number;
};

type VisionErrorEvent = {
  type: "error";
  code?: string;
  message?: string;
};

type VisionStreamEvent = VisionTaskEvent | VisionDoneEvent | VisionErrorEvent | { type: string };

interface Props {
  open: boolean;
  onClose: () => void;
  onSubmit: (tasks: Array<{ type: TaskType; title: string; time: string }>) => void | Promise<void>;
  onRequestOpen?: () => void;
  onAnalyzingChange?: (isAnalyzing: boolean) => void;
}

export interface AddTaskDialogHandle {
  openUploadPicker: () => void;
}

const AddTaskDialog = React.forwardRef<AddTaskDialogHandle, Props>(({ open, onClose, onSubmit, onRequestOpen, onAnalyzingChange }, ref) => {
  const [tasks, setTasks] = useState<TaskData[]>([]);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [timePickerOpen, setTimePickerOpen] = useState(false);
  const [timePickerTaskId, setTimePickerTaskId] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const visionWsRef = useRef<WebSocket | null>(null);
  const skipDefaultTaskInitRef = useRef(false);

  const getNextTime = (baseTime?: string) => {
    const d = new Date();
    if (baseTime) {
      const [h, m] = baseTime.split(":").map(Number);
      d.setHours(h, m);
    }
    d.setMinutes(d.getMinutes() + 15);
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  };

  useEffect(() => {
    if (open) {
      if (skipDefaultTaskInitRef.current) {
        skipDefaultTaskInitRef.current = false;
      } else {
        setTasks([{ id: Date.now().toString(), type: "pump", title: "吸奶", time: getNextTime() }]);
      }
      setIsAnalyzing(false);
    }
  }, [open]);

  useEffect(() => {
    onAnalyzingChange?.(isAnalyzing);
  }, [isAnalyzing, onAnalyzingChange]);

  useImperativeHandle(ref, () => ({
    openUploadPicker: () => {
      if (isAnalyzing) return;
      fileInputRef.current?.click();
    },
  }), [isAnalyzing]);

  useEffect(() => {
    return () => {
      if (visionWsRef.current) {
        try {
          visionWsRef.current.close();
        } catch {
          // ignore close error
        }
        visionWsRef.current = null;
      }
    };
  }, []);

  const addTask = () => {
    const lastTime = tasks.length > 0 ? tasks[tasks.length - 1].time : undefined;
    setTasks((prev) => [
      ...prev,
      { id: Date.now().toString(), type: "pump", title: "吸奶", time: getNextTime(lastTime) },
    ]);
  };

  const updateTask = (id: string, updates: Partial<TaskData>) => {
    setTasks((prev) =>
      prev.map((t) => {
        if (t.id !== id) return t;
        const updated = { ...t, ...updates };
        if (updates.type) {
          if (updates.type === "custom") {
            updated.title = "";
          } else {
            updated.title = updates.type === "pump" ? "吸奶" : "喂养";
          }
        }
        return updated;
      })
    );
  };

  const removeTask = (id: string) => {
    setTasks((prev) => prev.filter((t) => t.id !== id));
  };

  const normalizeVisionTaskType = (eventType: VisionEventType): TaskType => {
    if (eventType === "pump") return "pump";
    if (eventType === "breastfeed") return "feed";
    return "custom";
  };

  const buildVisionWsUrl = (): string => {
    const resolvedHttpUrl = resolveHttpRequestUrl("/v1/vision/events/stream");
    const wsBaseUrl = resolvedHttpUrl.startsWith("http://")
      ? `ws://${resolvedHttpUrl.slice("http://".length)}`
      : resolvedHttpUrl.startsWith("https://")
        ? `wss://${resolvedHttpUrl.slice("https://".length)}`
        : `${window.location.protocol === "https:" ? "wss" : "ws"}://${window.location.host}${resolvedHttpUrl.startsWith("/") ? resolvedHttpUrl : `/${resolvedHttpUrl}`}`;
    const token = String(import.meta.env?.VITE_API_TOKEN ?? "").trim();
    return token ? appendQueryParams(wsBaseUrl, { token }) : wsBaseUrl;
  };

  const parseVisionEvents = (fileId: string): Promise<TaskData[]> => {
    const wsUrl = buildVisionWsUrl();
    return new Promise((resolve, reject) => {
      const parsedTasks: TaskData[] = [];
      let settled = false;
      const ws = new WebSocket(wsUrl);
      visionWsRef.current = ws;

      const finalize = (fn: () => void) => {
        if (settled) return;
        settled = true;
        try {
          ws.close();
        } catch {
          // ignore close error
        }
        if (visionWsRef.current === ws) {
          visionWsRef.current = null;
        }
        fn();
      };

      ws.onopen = () => {
        ws.send(
          JSON.stringify({
            user_id: DEFAULT_CHAT_USER_ID,
            file_id: fileId,
          }),
        );
      };

      ws.onmessage = (messageEvent) => {
        let payload: VisionStreamEvent;
        try {
          payload = JSON.parse(String(messageEvent.data || "{}")) as VisionStreamEvent;
        } catch {
          return;
        }

        if (payload.type === "event") {
          const event = payload as VisionTaskEvent;
          parsedTasks.push({
            id: `${Date.now()}-${crypto.randomUUID()}`,
            type: normalizeVisionTaskType(event.event_type),
            title: event.event?.trim() || (event.event_type === "pump" ? "吸奶" : event.event_type === "breastfeed" ? "喂养" : ""),
            time: event.time,
          });
          return;
        }

        if (payload.type === "done") {
          finalize(() => resolve(parsedTasks));
          return;
        }

        if (payload.type === "error") {
          const errorEvent = payload as VisionErrorEvent;
          finalize(() => reject(new Error(errorEvent.message || "图片识别失败，请稍后重试。")));
        }
      };

      ws.onerror = () => {
        finalize(() => reject(new Error("图片识别连接失败，请检查服务是否可用。")));
      };

      ws.onclose = () => {
        if (!settled) {
          finalize(() => resolve(parsedTasks));
        }
      };
    });
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      try {
        setIsAnalyzing(true);
        const uploadResult = await uploadFile(DEFAULT_CHAT_USER_ID, file);
        const fileId = String((uploadResult as { id?: string; file_id?: string }).id ?? (uploadResult as { id?: string; file_id?: string }).file_id ?? "").trim();
        if (!fileId) {
          throw new Error("上传成功但未返回文件ID。");
        }
        const recognizedTasks = await parseVisionEvents(fileId);
        if (recognizedTasks.length === 0) {
          throw new Error("未识别到可添加的任务，请尝试更清晰的截图。");
        }
        setTasks((prev) => {
          // If the dialog was closed or there's only one default unchanged task, replace it. Otherwise append.
          if (!open || (prev.length === 1 && prev[0].type === "pump" && prev[0].title === "吸奶")) {
            return recognizedTasks;
          }
          return [...prev, ...recognizedTasks];
        });
        if (!open) {
          skipDefaultTaskInitRef.current = true;
          onRequestOpen?.();
        }
      } catch (error) {
        alert(error instanceof Error ? error.message : "截图识别失败，请稍后重试");
      } finally {
        setIsAnalyzing(false);
      }
    }
    // reset input so the same file can be uploaded again
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  const handleSubmit = async () => {
    const validTasks = tasks.filter((t) => t.type !== "custom" || t.title.trim().length > 0);
    if (validTasks.length > 0) {
      await Promise.resolve(onSubmit(validTasks));
    }
    onClose();
  };

  const isValid = tasks.length > 0 && tasks.every((t) => t.type !== "custom" || t.title.trim().length > 0);
  const pickerTask = tasks.find((t) => t.id === timePickerTaskId) || null;

  return (
    <>
      <input
        type="file"
        accept="image/*"
        className="hidden"
        ref={fileInputRef}
        onChange={handleFileUpload}
      />
      <AnimatePresence>
        {open && (
          <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[60] bg-foreground/20 backdrop-blur-sm"
            onClick={onClose}
          />
          <motion.div
            initial={{ y: "100%", opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: "100%", opacity: 0 }}
            transition={{ type: "spring", damping: 28, stiffness: 300 }}
            className="fixed inset-x-0 bottom-0 z-[60] w-full max-w-lg mx-auto rounded-t-3xl bg-card border-t border-border shadow-2xl flex flex-col"
            style={{ maxHeight: "90vh", paddingBottom: "max(1rem, env(safe-area-inset-bottom))" }}
          >
            {/* Header */}
            <div className="flex items-center justify-between px-5 pt-5 pb-3 border-b border-border/40 shrink-0">
              <h3 className="text-base font-bold text-foreground">添加任务</h3>
              <button onClick={onClose} className="p-1 rounded-full hover:bg-secondary transition-colors">
                <X className="w-5 h-5 text-muted-foreground" />
              </button>
            </div>

            {/* Task List */}
            <div className="flex-1 px-5 overflow-y-auto overscroll-contain min-h-0">
              <div className="py-4 space-y-4">
                {isAnalyzing && (
                  <div className="flex items-center gap-2 rounded-2xl border border-primary/15 bg-primary/5 px-3 py-2 text-[12px] font-bold text-primary">
                    <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    正在识别日程截图...
                  </div>
                )}
                <AnimatePresence initial={false}>
                  {tasks.map((task, index) => (
                    <motion.div
                      key={task.id}
                      initial={{ opacity: 0, height: 0, scale: 0.95 }}
                      animate={{ opacity: 1, height: "auto", scale: 1 }}
                      exit={{ opacity: 0, height: 0, scale: 0.95 }}
                      transition={{ duration: 0.2 }}
                      className="p-4 bg-secondary/30 border border-border/50 rounded-2xl relative"
                    >
                      <div className="flex items-center justify-between mb-3">
                        <span className="text-[11px] font-bold text-muted-foreground bg-background px-2 py-0.5 rounded-md border border-border/50">
                          任务 {index + 1}
                        </span>
                        {tasks.length > 1 && (
                          <button
                            onClick={() => removeTask(task.id)}
                            className="text-muted-foreground hover:text-destructive transition-colors p-1"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        )}
                      </div>

                      <div className="flex gap-2 mb-4">
                        {[
                          { key: "pump", label: "🤱 吸奶" },
                          { key: "feed", label: "🍼 喂养" },
                          { key: "custom", label: "⭐ 自定义" },
                        ].map((t) => (
                          <button
                            key={t.key}
                            onClick={() => updateTask(task.id, { type: t.key as TaskType })}
                            className={cn(
                              "flex-1 py-2 rounded-xl text-[12px] font-semibold transition-all border",
                              task.type === t.key
                                ? "bg-primary/10 border-primary/30 text-foreground shadow-sm"
                                : "bg-background border-border text-muted-foreground hover:bg-muted"
                            )}
                          >
                            {t.label}
                          </button>
                        ))}
                      </div>

                      <div className="space-y-3">
                        {task.type === "custom" && (
                          <motion.div
                            initial={{ opacity: 0, height: 0 }}
                            animate={{ opacity: 1, height: "auto" }}
                            className="overflow-hidden"
                          >
                            <Input
                              type="text"
                              value={task.title}
                              onChange={(e) => updateTask(task.id, { title: e.target.value })}
                              placeholder="例如：带娃打疫苗、哄睡"
                              className="h-10 rounded-xl bg-background border-border/50 text-[13px]"
                            />
                          </motion.div>
                        )}

                        <div className="flex items-center gap-2">
                          <label className="text-[12px] font-semibold text-muted-foreground shrink-0 w-14">
                            计划时间
                          </label>
                          <button
                            type="button"
                            onClick={() => {
                              setTimePickerTaskId(task.id);
                              setTimePickerOpen(true);
                            }}
                            className="flex-1 h-10 rounded-xl bg-background border border-border/50 px-3 text-[14px] font-medium text-foreground text-left outline-none focus:border-primary/50 transition-colors"
                          >
                            {task.time}
                          </button>
                        </div>
                      </div>
                    </motion.div>
                  ))}
                </AnimatePresence>

                <Button
                  onClick={addTask}
                  variant="outline"
                  className="w-full h-12 rounded-2xl border-dashed border-2 border-border text-muted-foreground font-bold hover:text-foreground hover:border-foreground/30 bg-transparent"
                >
                  <Plus className="w-4 h-4 mr-1.5" />
                  手动添加一项
                </Button>
              </div>
            </div>

            {/* Footer Action */}
            <div className="p-5 pt-3 border-t border-border/40 shrink-0 bg-card">
              <Button
                onClick={() => {
                  void handleSubmit().catch((err: unknown) => {
                    alert(err instanceof Error ? err.message : "添加任务失败，请稍后重试");
                  });
                }}
                disabled={!isValid || isAnalyzing}
                className="w-full h-14 rounded-2xl text-base font-bold shadow-md"
              >
                确认添加 ({tasks.length}项)
              </Button>
            </div>
          </motion.div>
          <TimeWheelPickerSheet
            open={timePickerOpen}
            value={pickerTask?.time || "00:00"}
            title="设置计划时间"
            onClose={() => setTimePickerOpen(false)}
            onConfirm={(nextTime) => {
              if (timePickerTaskId) {
                updateTask(timePickerTaskId, { time: nextTime });
              }
            }}
          />
          </>
        )}
      </AnimatePresence>
    </>
  );
});

AddTaskDialog.displayName = "AddTaskDialog";

export default AddTaskDialog;
