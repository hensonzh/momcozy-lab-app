import React, { useState, useMemo, useCallback, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { motion, AnimatePresence, PanInfo } from "framer-motion";
import { ChevronLeft, ChevronRight, Plus, Pencil, Trash2, Package, Droplets, Clock, TrendingUp, HelpCircle, RefreshCw } from "lucide-react";
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip as RechartsTooltip, ReferenceArea, ReferenceLine } from "recharts";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import { cn } from "@/lib/utils";
import { pumpRecords, type PumpRecord } from "@/data/mockData";
import ManualEntryDialog from "@/components/records/ManualEntryDialog";
import RecordAgentDrawer from "@/components/records/RecordAgentDrawer";
import ConfirmDialog from "@/components/records/ConfirmDialog";
import { useVolumeUnit, formatVol, unitLabel } from "@/lib/volumeUnit";

/* ── helpers ── */
const isPumpMilk = (r: PumpRecord) =>
  r.source === "device" || r.subLabel === "补录";

const isInventory = (r: PumpRecord) =>
  r.category === "inventory" || r.subLabel === "补录" || r.subLabel === "配方奶" || r.source === "device" || (!r.category && r.subLabel !== "亲喂" && r.subLabel !== "瓶喂");


const isFormula = (r: PumpRecord) => r.subLabel === "配方奶";

const sourceBadge: Record<string, { label: string; icon: string; className: string }> = {
  device: { label: "设备", icon: "📱", className: "bg-primary/10 text-primary" },
  manual: { label: "手动", icon: "✍️", className: "bg-mai-warm/15 text-mai-warm" },
  voice:  { label: "Mai记", icon: "✨", className: "bg-mai-blush/15 text-mai-glow" },
};

const milkTypeBadge: Record<string, { label: string; className: string }> = {
  "母乳":   { label: "🤱 母乳", className: "bg-primary/10 text-primary" },
  "配方奶": { label: "🧪 配方奶", className: "bg-mai-warm/15 text-mai-warm" },
  "亲喂":   { label: "🤱 亲喂", className: "bg-accent/50 text-accent-foreground" },
  "瓶喂":   { label: "🍼 瓶喂", className: "bg-primary/10 text-primary" },
};

type StageTickProps = {
  x?: number;
  y?: number;
  payload?: {
    value?: number;
  };
};

function getMilkType(r: PumpRecord): string {
  if (r.subLabel === "配方奶") return "配方奶";
  if (r.subLabel === "亲喂") return "亲喂";
  if (r.subLabel === "瓶喂") return "瓶喂";
  return "母乳";
}

/* ── Swipeable record row ── */
const SwipeRow: React.FC<{
  record: PumpRecord;
  onDelete: (id: string) => void;
  onEdit: (id: string) => void;
  canModify: boolean;
  volUnit: "mL" | "oz";
}> = ({ record, onDelete, onEdit, canModify, volUnit }) => {
  const [offset, setOffset] = useState(0);
  const badge = sourceBadge[record.source];
  const typeKey = getMilkType(record);
  const typeBadge = milkTypeBadge[typeKey];

  const handleDragEnd = (_: unknown, info: PanInfo) => {
    if (canModify && info.offset.x < -80) setOffset(-120);
    else setOffset(0);
  };

  const isFormulaRow = isFormula(record);

  return (
    <div className="relative overflow-hidden rounded-xl">
      {canModify && (
        <div className="absolute inset-y-0 right-0 flex items-stretch">
          <button
            onClick={() => { onEdit(record.id); setOffset(0); }}
            className="w-14 flex items-center justify-center bg-mai-warm/80 text-primary-foreground"
          >
            <Pencil className="w-4 h-4" />
          </button>
          <button
            onClick={() => { onDelete(record.id); setOffset(0); }}
            className="w-14 flex items-center justify-center bg-destructive text-destructive-foreground"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      )}

      <motion.div
        drag={canModify ? "x" : false}
        dragConstraints={{ left: -120, right: 0 }}
        dragElastic={0.1}
        onDragEnd={handleDragEnd}
        animate={{ x: offset }}
        className={cn(
          "relative border rounded-xl px-3.5 py-3 flex items-center justify-between cursor-grab active:cursor-grabbing z-10",
          isFormulaRow
            ? "bg-mai-warm/5 border-mai-warm/20"
            : "bg-card border-border"
        )}
      >
        <div className="flex items-center gap-2.5">
          <div className="flex flex-col items-start">
            <span className="text-base font-bold text-foreground">
              {record.subLabel === "亲喂"
                ? `🤱 ${record.durationMin}分钟`
                : `${isFormulaRow ? "🧪" : "🍼"} ${formatVol(record.totalMl, volUnit)}${unitLabel(volUnit)}`}
            </span>
            <span className="text-[10px] text-muted-foreground">
              {record.subLabel === "亲喂" ? "亲喂" : record.durationMin > 0 ? `${record.durationMin}分钟` : "--分钟"}
            </span>
          </div>
          {typeBadge && (
            <span className={cn("text-[10px] font-semibold px-1.5 py-0.5 rounded-full", typeBadge.className)}>
              {typeBadge.label}
            </span>
          )}
          <span className={cn("text-[10px] font-semibold px-1.5 py-0.5 rounded-full", badge.className)}>
            {badge.icon} {badge.label}
          </span>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-xs font-medium text-muted-foreground">{record.time}</span>
          {canModify && (
            <button
              onClick={(e) => { e.stopPropagation(); onDelete(record.id); }}
              className="p-1 rounded-full text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
            >
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </motion.div>
    </div>
  );
};

/* ── Tooltip helper with auto-dismiss — positioned via portal-like fixed approach ── */
const InfoTip: React.FC<{ show: boolean; toggle: () => void; text: string }> = ({ show, toggle, text }) => {
  const timerRef = useRef<ReturnType<typeof setTimeout>>();
  const btnRef = useRef<HTMLButtonElement>(null);
  const [pos, setPos] = useState<{ top: number; left: number } | null>(null);

  useEffect(() => {
    if (show) {
      timerRef.current = setTimeout(() => toggle(), 2000);
      if (btnRef.current) {
        const rect = btnRef.current.getBoundingClientRect();
        setPos({ top: rect.top - 8, left: rect.left + rect.width / 2 });
      }
      return () => clearTimeout(timerRef.current);
    }
  }, [show, toggle]);

  return (
    <button ref={btnRef} onClick={(e) => { e.stopPropagation(); toggle(); }} className="relative ml-0.5">
      <HelpCircle className="w-3 h-3 text-muted-foreground" />
      <AnimatePresence>
        {show && pos && (
          <motion.div
            initial={{ opacity: 0, y: 4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 4 }}
            transition={{ duration: 0.2 }}
            className="fixed w-48 p-2 rounded-lg bg-foreground text-background text-[10px] leading-tight z-[100] shadow-lg"
            style={{ top: pos.top, left: pos.left, transform: 'translate(-50%, -100%)' }}
          >
            {text}
            <div className="absolute top-full left-1/2 -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-foreground" />
          </motion.div>
        )}
      </AnimatePresence>
    </button>
  );
};

/* ── Main Records Page ── */
const Records: React.FC = () => {
  const navigate = useNavigate();
  const today = "2026-03-09";
  const [records, setRecords] = useState<PumpRecord[]>(pumpRecords);
  const [agentOpen, setAgentOpen] = useState(false);
  const [entryOpen, setEntryOpen] = useState(false);
  const [editingRecord, setEditingRecord] = useState<PumpRecord | null>(null);
  const [confirmState, setConfirmState] = useState<{ type: "delete" | "edit"; record: PumpRecord; pendingRecord?: PumpRecord } | null>(null);
  const [volUnit, toggleUnit] = useVolumeUnit();

  const todayRecords = useMemo(
    () => records.filter((r) => r.date === today).sort((a, b) => a.time.localeCompare(b.time)),
    [records]
  );

  const inventoryRecords = useMemo(() => todayRecords.filter(isInventory), [todayRecords]);

  const inventoryTotal = useMemo(() => todayRecords.filter(isInventory).reduce((s, r) => s + r.totalMl, 0), [todayRecords]);
  const deviceMilkTotal = useMemo(() => todayRecords.filter(r => r.source === "device").reduce((s, r) => s + r.totalMl, 0), [todayRecords]);
  const deviceSessionCount = useMemo(() => todayRecords.filter(r => r.source === "device").length, [todayRecords]);

  const [showDeviceTooltip, setShowDeviceTooltip] = useState(false);
  const [showPumpCountTooltip, setShowPumpCountTooltip] = useState(false);
  const [showWeekAvgTooltip, setShowWeekAvgTooltip] = useState(false);

  const weekPumpAvg = useMemo(() => {
    const sysDate = new Date(today);
    const dayTotals: number[] = [];
    for (let i = 1; i <= 7; i++) {
      const d = new Date(sysDate);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().slice(0, 10);
      const dayTotal = records.filter(r => r.date === dateStr && isPumpMilk(r)).reduce((s, r) => s + r.totalMl, 0);
      dayTotals.push(dayTotal);
    }
    const sum = dayTotals.reduce((s, v) => s + v, 0);
    return Math.round(sum / 7);
  }, [records]);

  const chartData = useMemo(() => {
    const sysDate = new Date(today);
    const data: { date: string; value: number }[] = [];
    for (let i = 7; i >= 1; i--) {
      const d = new Date(sysDate);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().slice(0, 10);
      const label = `${String(d.getMonth() + 1).padStart(2, "0")}/${String(d.getDate()).padStart(2, "0")}`;
      const totalMl = records.filter(r => r.date === dateStr && isPumpMilk(r)).reduce((s, r) => s + r.totalMl, 0);
      const value = volUnit === "oz" ? +(totalMl * 0.033814).toFixed(1) : totalMl;
      data.push({ date: label, value });
    }
    return data;
  }, [records, volUnit]);

  // Listen for inventory records added from other pages (e.g. chat / agent flows)
  useEffect(() => {
    const handler = (e: Event) => {
      const record = (e as CustomEvent).detail as PumpRecord;
      if (record) setRecords(prev => [...prev, record]);
    };
    window.addEventListener("inventoryRecordAdded", handler);
    return () => window.removeEventListener("inventoryRecordAdded", handler);
  }, []);

  const canModify = (rec: PumpRecord) => rec.source === "manual" || rec.source === "voice";

  const handleDelete = useCallback((id: string) => {
    const rec = records.find((r) => r.id === id);
    if (rec) setConfirmState({ type: "delete", record: rec });
  }, [records]);

  const handleEdit = useCallback((id: string) => {
    const rec = records.find((r) => r.id === id);
    if (rec && canModify(rec)) {
      setEditingRecord(rec);
      setEntryOpen(true);
    }
  }, [records]);

  const handleEntrySubmit = useCallback((newRecord: PumpRecord) => {
    if (editingRecord) {
      setConfirmState({ type: "edit", record: editingRecord, pendingRecord: newRecord });
      setEditingRecord(null);
    } else {
      setRecords((prev) => [...prev, newRecord]);
    }
  }, [editingRecord]);

  const handleConfirm = useCallback(() => {
    if (!confirmState) return;
    if (confirmState.type === "delete") {
      setRecords((prev) => prev.filter((r) => r.id !== confirmState.record.id));
    } else if (confirmState.type === "edit" && confirmState.pendingRecord) {
      const updated = { ...confirmState.pendingRecord, source: "manual" as const };
      setRecords((prev) => prev.map((r) => r.id === confirmState.record.id ? updated : r));
    }
    setConfirmState(null);
  }, [confirmState]);

  const handleAgentAddRecord = useCallback((record: PumpRecord) => {
    setRecords((prev) => [...prev, record]);
  }, []);

  return (
    <div
      className="flex flex-col relative"
      style={{
        height: "calc(100vh - var(--top-safe))",
        maxHeight: "calc(100vh - var(--top-safe))",
      }}
    >
      {/* Header */}
      <div className="flex-shrink-0 px-4 pt-4 pb-2">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-bold text-foreground flex items-center gap-1.5">📊 妈妈点滴</h1>
          <div className="flex items-center gap-1 text-sm text-muted-foreground font-medium">
            <ChevronLeft className="w-4 h-4" />
            <span>2026年3月</span>
            <ChevronRight className="w-4 h-4" />
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-4 pb-24 space-y-4">
        {/* ═══ Combined: Stats + Trend Chart ═══ */}
        <div className="glass-panel rounded-2xl p-4 space-y-3">
          <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center justify-between">
            <span>🌸 今日吸奶器使用</span>
            <button
              onClick={toggleUnit}
              className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-muted/50 hover:bg-muted transition-colors text-[10px] font-bold text-foreground normal-case tracking-normal"
            >
              <RefreshCw className="w-3 h-3 text-muted-foreground" />
              {volUnit}
            </button>
          </p>

          {/* Stats row */}
          <div className="grid grid-cols-3 gap-2 text-center">
            <div className="bg-primary/5 rounded-xl py-2 px-1">
              <div className="flex items-center justify-center gap-0.5">
                <Droplets className="w-3.5 h-3.5 text-primary flex-shrink-0" />
                <span className="text-lg font-bold text-foreground">{formatVol(deviceMilkTotal, volUnit)}</span>
                <span className="text-[9px] text-muted-foreground">{unitLabel(volUnit)}</span>
                <InfoTip show={showDeviceTooltip} toggle={() => setShowDeviceTooltip(!showDeviceTooltip)} text="吸奶器母乳量 = 今日通过吸奶器设备记录的泵奶总量，不含手动补录和配方奶。" />
              </div>
              <p className="text-[9px] text-muted-foreground mt-0.5 leading-tight">吸奶器母乳量</p>
            </div>
            <div className="bg-mai-warm/5 rounded-xl py-2 px-1">
              <div className="flex items-center justify-center gap-0.5">
                <Clock className="w-3.5 h-3.5 text-mai-warm flex-shrink-0" />
                <span className="text-lg font-bold text-foreground">{deviceSessionCount}</span>
                <span className="text-[9px] text-muted-foreground">次</span>
                <InfoTip show={showPumpCountTooltip} toggle={() => setShowPumpCountTooltip(!showPumpCountTooltip)} text="吸奶次数 = 今日通过吸奶器设备记录的吸奶次数，不含手动补录和其他记录。" />
              </div>
              <p className="text-[9px] text-muted-foreground mt-0.5 leading-tight">吸奶次数</p>
            </div>
            <div className="bg-accent/10 rounded-xl py-2 px-1">
              <div className="flex items-center justify-center gap-0.5">
                <TrendingUp className="w-3.5 h-3.5 text-mai-glow flex-shrink-0" />
                <span className="text-lg font-bold text-foreground">{formatVol(weekPumpAvg, volUnit)}</span>
                <span className="text-[9px] text-muted-foreground">{unitLabel(volUnit)}</span>
                <InfoTip show={showWeekAvgTooltip} toggle={() => setShowWeekAvgTooltip(!showWeekAvgTooltip)} text="过去1周平均日补录奶量 = 过去7天内每日（吸奶器泵奶 + 吸奶补录）总量的平均值。" />
              </div>
              <p className="text-[9px] text-muted-foreground mt-0.5 leading-tight">周均日补录奶量</p>
            </div>
          </div>

          {/* Trend chart */}
          <div className="border-t border-border/50 pt-3">
            <div className="flex items-start justify-between gap-2 mb-1">
              <p className="text-[10px] font-semibold text-muted-foreground">📈 过去1周日补录奶量趋势</p>
              <p className="text-[8px] text-muted-foreground/70 italic text-right leading-tight max-w-[130px]">
                补录奶量 = 吸奶器 + 补录<br/>波动正常，放轻松就好 💛
              </p>
            </div>
            <div className="h-40">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData} margin={{ top: 5, right: 10, bottom: 0, left: 0 }}>
                  <defs>
                    <linearGradient id="fillGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="hsl(var(--primary))" stopOpacity={0.3} />
                      <stop offset="100%" stopColor="hsl(var(--primary))" stopOpacity={0.02} />
                    </linearGradient>
                  </defs>
                  {volUnit === "mL" ? (
                    <>
                      <ReferenceArea yAxisId="ml" y1={0} y2={100} fill="hsl(var(--mai-warm))" fillOpacity={0.06} />
                      <ReferenceArea yAxisId="ml" y1={100} y2={750} fill="hsl(var(--primary))" fillOpacity={0.06} />
                      <ReferenceArea yAxisId="ml" y1={750} y2={1200} fill="hsl(var(--mai-glow))" fillOpacity={0.08} />
                      <ReferenceLine yAxisId="ml" y={100} stroke="hsl(var(--mai-warm))" strokeDasharray="3 3" strokeOpacity={0.3} />
                      <ReferenceLine yAxisId="ml" y={750} stroke="hsl(var(--mai-glow))" strokeDasharray="3 3" strokeOpacity={0.3} />
                    </>
                  ) : (
                    <>
                      <ReferenceArea yAxisId="ml" y1={0} y2={3.4} fill="hsl(var(--mai-warm))" fillOpacity={0.06} />
                      <ReferenceArea yAxisId="ml" y1={3.4} y2={25.4} fill="hsl(var(--primary))" fillOpacity={0.06} />
                      <ReferenceArea yAxisId="ml" y1={25.4} y2={42} fill="hsl(var(--mai-glow))" fillOpacity={0.08} />
                      <ReferenceLine yAxisId="ml" y={3.4} stroke="hsl(var(--mai-warm))" strokeDasharray="3 3" strokeOpacity={0.3} />
                      <ReferenceLine yAxisId="ml" y={25.4} stroke="hsl(var(--mai-glow))" strokeDasharray="3 3" strokeOpacity={0.3} />
                    </>
                  )}
                  <XAxis dataKey="date" tick={{ fontSize: 9 }} tickLine={false} axisLine={false} />
                  <YAxis
                    yAxisId="ml"
                    tickLine={false}
                    axisLine={false}
                    domain={volUnit === "oz" ? [0, 42] : [0, 1200]}
                    ticks={volUnit === "oz" ? [0, 3.4, 10, 17, 25.4, 35] : [0, 100, 300, 500, 750, 1000]}
                    width={28}
                    tick={{ fontSize: 8, fill: "hsl(var(--muted-foreground))" }}
                    tickFormatter={(v: number) => `${v}`}
                  />
                  <YAxis
                    yAxisId="stage"
                    orientation="right"
                    tickLine={false}
                    axisLine={false}
                    domain={volUnit === "oz" ? [0, 42] : [0, 1200]}
                    ticks={volUnit === "oz" ? [1.7, 14.4, 33.7] : [50, 425, 975]}
                    width={40}
                    tick={({ x = 0, y = 0, payload }: StageTickProps) => {
                      const mlLabels: Record<number, string> = { 50: "启动期", 425: "建立期", 975: "供需平衡" };
                      const ozLabels: Record<number, string> = { 1.7: "启动期", 14.4: "建立期", 33.7: "供需平衡" };
                      const labels = volUnit === "oz" ? ozLabels : mlLabels;
                      const colors: Record<number, string> = volUnit === "oz"
                        ? { 1.7: "hsl(var(--mai-warm))", 14.4: "hsl(var(--primary))", 33.7: "hsl(var(--mai-glow))" }
                        : { 50: "hsl(var(--mai-warm))", 425: "hsl(var(--primary))", 975: "hsl(var(--mai-glow))" };
                      return (
                        <text x={x} y={y} textAnchor="start" fontSize={8} fill={colors[payload?.value ?? 0]} fontWeight={600} dy={3} dx={4}>
                          {labels[payload?.value ?? 0] || ""}
                        </text>
                      );
                    }}
                  />
                  <RechartsTooltip
                    contentStyle={{ fontSize: 11, borderRadius: 12, border: "none", boxShadow: "0 4px 12px rgba(0,0,0,0.08)" }}
                    formatter={(val: number) => [`${val}${unitLabel(volUnit)}`, "补录奶量"]}
                  />
                  <Area yAxisId="ml" type="monotone" dataKey="value" stroke="hsl(var(--primary))" strokeWidth={2} fill="url(#fillGrad)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Mai comment inside card */}
          <button
            onClick={() => setAgentOpen(true)}
            className="flex items-center gap-2 w-full text-left group"
          >
            <MaiAvatar emotion="happy" size="sm" animate />
            <span className="text-[11px] text-primary font-semibold group-hover:text-primary/80 transition-colors">
              ←问问M.ai呀~
            </span>
          </button>
          <p className="text-[11px] text-muted-foreground italic leading-relaxed pl-10">
            "最近补录奶量稳步上升，今天也很棒哦～继续保持，你和宝宝都在进步中 💕"
          </p>
        </div>

        {/* ═══ Today Records — split into Inventory & Feeding ═══ */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider">📝 今日记录</p>
            <button
              onClick={() => { setEditingRecord(null); setEntryOpen(true); }}
              className="flex items-center gap-1 text-[11px] font-semibold text-primary hover:text-primary/80 transition-colors"
            >
              <Plus className="w-3.5 h-3.5" /> 手动记录
            </button>
          </div>

          {/* Inventory section */}
          <div className="space-y-2">
            <div className="flex items-center gap-1.5">
              <Package className="w-3.5 h-3.5 text-primary" />
              <span className="text-[11px] font-bold text-primary">可用母乳库存</span>
              <span className="text-base font-extrabold text-primary ml-auto">{formatVol(inventoryTotal, volUnit)} <span className="text-xs font-bold">{unitLabel(volUnit)}</span></span>
            </div>
            <AnimatePresence>
              {inventoryRecords.map((rec) => (
                <motion.div
                  key={rec.id}
                  layout
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, x: -200 }}
                  transition={{ duration: 0.25 }}
                >
                  <SwipeRow record={rec} onDelete={handleDelete} onEdit={handleEdit} canModify={canModify(rec)} volUnit={volUnit} />
                </motion.div>
              ))}
            </AnimatePresence>
            {inventoryRecords.length === 0 && (
              <p className="text-center text-[11px] text-muted-foreground py-4">暂无库存记录</p>
            )}
          </div>
        </div>

        {/* Baby link — moved to bottom */}
        <button
          onClick={() => navigate("/status")}
          className="w-full text-center text-[12px] font-semibold text-primary hover:text-primary/80 transition-colors py-2"
        >
          ✨ 想看看宝宝吗？ &gt;
        </button>
      </div>

      {/* Agent Drawer */}
      <RecordAgentDrawer
        open={agentOpen}
        onClose={() => setAgentOpen(false)}
        todayRecords={todayRecords}
        todayTotal={inventoryTotal}
        onAddRecord={handleAgentAddRecord}
      />

      {/* Manual Entry Dialog */}
      <ManualEntryDialog
        open={entryOpen}
        onClose={() => { setEntryOpen(false); setEditingRecord(null); }}
        onSubmit={handleEntrySubmit}
        editRecord={editingRecord}
        recordDateIso={today}
      />

      {/* Confirm Dialog */}
      <ConfirmDialog
        open={!!confirmState}
        title={confirmState?.type === "delete" ? "确认删除" : "确认修改"}
        description={
          confirmState?.type === "delete"
            ? "确定要删除这条记录吗？此操作不可撤销。"
            : confirmState?.record.source === "voice"
              ? "修改后该记录将从「来自M.ai」变为「手动」类型，确认修改吗？"
              : "确认要修改这条记录吗？"
        }
        onConfirm={handleConfirm}
        onCancel={() => setConfirmState(null)}
        confirmLabel={confirmState?.type === "delete" ? "删除" : "确认修改"}
        destructive={confirmState?.type === "delete"}
      />
    </div>
  );
};

export default Records;
