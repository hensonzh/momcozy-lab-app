import {
  getPumpProcessData,
  uploadPumpProcess,
  uploadPumpWorkstate,
} from "@/lib/agentApi";
import type {
  ChatRichTextButtonItem,
  ChatRichTextPayload,
  PumpProcessDataBody,
  PumpProcessDataSide,
  PumpDeviceState,
  PumpProcessBody,
  PumpProcessSide,
  PumpWorkstateBody,
  UploadPumpWorkstateResponseData,
} from "@/lib/agentApiTypes";
import { deviceStore, type DeviceSide, type StoredDeviceInfo } from "@/lib/deviceStore";
import { getRuntimeUserId } from "@/lib/debugUserConfig";
import { createScopedConsole } from "@/lib/logger";
import { setProcessAll } from "@/lib/pumpSessionProgress";

const console = createScopedConsole("pumpAgentUpload");
const DEFAULT_CHAT_USER_ID = getRuntimeUserId(import.meta.env.VITE_DEFAULT_USER_ID as string | undefined);
const PROCESS_UPLOAD_INTERVAL_MS = 10000;
const PROCESS_DATA_INTERVAL_MS = 1000;
const PROCESS_CAP_FRAME_SIZE = 20;
const SOURCE_TTL_MS = 6000;

type PumpAgentUploadSource = "device" | "app" | "agent";
type SideSourceState = { source: PumpAgentUploadSource; expiresAt: number };
type PumpProcessReplyListener = (payload: { text: string; buttons: ChatRichTextButtonItem[] }) => void;
type PumpProcessProgressListener = (payload: { processL: number; processR: number; processAll: number }) => void;
type PumpProcessStep = "start" | "running" | "pause" | "stop";
type PumpProcessFrame = {
  time: string;
  cap_data: number;
  milk_reel: number;
  bandpower: number;
  milk: number;
};

const sideSourceMap: Record<"L" | "R", SideSourceState> = {
  L: { source: "device", expiresAt: 0 },
  R: { source: "device", expiresAt: 0 },
};

const processSnapshotMap: Record<"L" | "R", PumpProcessSide> = {
  L: { time: new Date().toISOString(), process: 0, cap_data: 0, milk_reel: 0, bandpower: 0, milk: 0 },
  R: { time: new Date().toISOString(), process: 0, cap_data: 0, milk_reel: 0, bandpower: 0, milk: 0 },
};

let started = false;
let unsubscribeDeviceStore: (() => void) | null = null;
let processTimer: number | null = null;
let processDataTimer: number | null = null;
let workstateSignature = "";
let workstateUploading = false;
let processUploading = false;
let processDataFetching = false;
const processReplyListenerSet = new Set<PumpProcessReplyListener>();
const processProgressListenerSet = new Set<PumpProcessProgressListener>();
const processFrameMap: Record<"L" | "R", PumpProcessFrame[]> = { L: [], R: [] };
const processFrameLastTsMap: Record<"L" | "R", string> = { L: "", R: "" };
const processStepMap: Record<"L" | "R", PumpProcessStep> = { L: "stop", R: "stop" };
const processStopMarkedMap: Record<"L" | "R", boolean> = { L: false, R: false };
const processPauseMarkedMap: Record<"L" | "R", boolean> = { L: false, R: false };
const processPrevConnectedMap: Record<"L" | "R", boolean> = { L: false, R: false };
const processProgressMap: Record<"L" | "R", number> = { L: 0, R: 0 };
let processProgressAll = 0;

function composeMilkReelFromStore(device: StoredDeviceInfo | null | undefined): number {
  const milkFlagBit = Number(device?.milkFlag ?? 0) & 0x01;
  const moFlagBit = Number(device?.moFlag ?? 0) & 0x01;
  return (moFlagBit << 1) | milkFlagBit;
}

export function onPumpAgentUploadProcessReply(listener: PumpProcessReplyListener): () => void {
  processReplyListenerSet.add(listener);
  console.log("process reply listener added", { listener_count: processReplyListenerSet.size });
  return () => {
    processReplyListenerSet.delete(listener);
    console.log("process reply listener removed", { listener_count: processReplyListenerSet.size });
  };
}

function emitPumpProcessReply(text: string, buttons: ChatRichTextButtonItem[] = []): void {
  console.log("process reply emit", {
    listener_count: processReplyListenerSet.size,
    text,
    button_count: buttons.length,
  });
  for (const listener of processReplyListenerSet) {
    try {
      listener({ text, buttons });
    } catch (error) {
      console.warn("process reply listener failed", error);
    }
  }
}

export function onPumpAgentUploadProcessProgress(listener: PumpProcessProgressListener): () => void {
  processProgressListenerSet.add(listener);
  return () => {
    processProgressListenerSet.delete(listener);
  };
}

export function getPumpAgentUploadProcessProgress(): { processL: number; processR: number; processAll: number } {
  return { processL: processProgressMap.L, processR: processProgressMap.R, processAll: processProgressAll };
}

function emitPumpAgentUploadProcessProgress(): void {
  const payload = getPumpAgentUploadProcessProgress();
  /** 会话岛等全局 UI 不依赖 PumpSession 挂载即可更新 process_all（真机采样在 pumpAgentUpload 内持续推进） */
  setProcessAll(payload.processAll);
  for (const listener of processProgressListenerSet) {
    try {
      listener(payload);
    } catch (error) {
      console.warn("process progress listener failed", error);
    }
  }
}

export function markPumpAgentUploadProcessStepStop(side: "L" | "R" | "both"): void {
  if (side === "both") {
    processStopMarkedMap.L = true;
    processStopMarkedMap.R = true;
    return;
  }
  processStopMarkedMap[side] = true;
}

export function markPumpAgentUploadProcessStepPause(side: "L" | "R" | "both"): void {
  if (side === "both") {
    processPauseMarkedMap.L = true;
    processPauseMarkedMap.R = true;
    return;
  }
  processPauseMarkedMap[side] = true;
}

export function normalizePumpAgentUploadRichTextButtonList(raw: unknown): ChatRichTextButtonItem[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((item) => {
    const obj = item && typeof item === "object" ? (item as Record<string, unknown>) : {};
    return {
      text: typeof obj.text === "string" ? obj.text : "",
      value: typeof obj.value === "string" ? obj.value : "",
      type: typeof obj.type === "string" ? obj.type : "",
      highlight: Boolean(obj.highlight),
      icon: typeof obj.icon === "string" ? obj.icon : "",
    };
  });
}

export function normalizePumpAgentUploadDirectRichText(raw: unknown): ChatRichTextPayload | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;
  return {
    title: typeof obj.title === "string" ? obj.title : "",
    content: typeof obj.content === "string" ? obj.content : "",
    button: normalizePumpAgentUploadRichTextButtonList(obj.button),
    card: Array.isArray(obj.card) ? obj.card : [],
    action: Array.isArray(obj.action) ? obj.action : [],
  };
}

export function buildPumpAgentUploadWorkstateReplyPayload(data?: UploadPumpWorkstateResponseData): {
  text: string;
  richText: ChatRichTextPayload | null;
} | null {
  if (!data || !data.need_reply) return null;
  const richText = normalizePumpAgentUploadDirectRichText(data.direct_rich_text);
  const text = typeof data.output === "string" ? data.output.trim() : "";
  if (!text && !richText) return null;
  return { text, richText };
}

function resolveSource(side: "L" | "R"): PumpAgentUploadSource {
  const now = Date.now();
  const entry = sideSourceMap[side];
  if (entry.expiresAt > now) return entry.source;
  return "device";
}

export function setPumpAgentUploadOperationSource(
  side: "L" | "R" | "both",
  source: PumpAgentUploadSource,
  ttlMs = SOURCE_TTL_MS,
): void {
  const expiresAt = Date.now() + Math.max(500, ttlMs);
  if (side === "both") {
    sideSourceMap.L = { source, expiresAt };
    sideSourceMap.R = { source, expiresAt };
    return;
  }
  sideSourceMap[side] = { source, expiresAt };
}

export function markPumpAgentUploadDeviceSourceByPacket(
  cid: number,
  deviceId?: string,
): void {
  const deviceSourceCidSet = new Set([0xe0, 0xe1, 0xd0, 0xd1, 0xd4, 0xd5, 0xd6]);
  if (!deviceSourceCidSet.has(cid)) return;
  if (!deviceId) {
    setPumpAgentUploadOperationSource("both", "device");
    return;
  }
  const store = deviceStore.get();
  let matched = false;
  if (store.L?.deviceId === deviceId) {
    setPumpAgentUploadOperationSource("L", "device");
    matched = true;
  }
  if (store.R?.deviceId === deviceId) {
    setPumpAgentUploadOperationSource("R", "device");
    matched = true;
  }
  if (!matched) setPumpAgentUploadOperationSource("both", "device");
}

function mapStoredDeviceToWorkstate(device: StoredDeviceInfo | null, side: "L" | "R"): PumpDeviceState {
  const nowIso = new Date().toISOString();
  const source = resolveSource(side);
  const timestamp = source === "device" ? (device?.lastDeviceWorkstateTs || nowIso) : nowIso;
  if (!device) return { state: 4, timestamp: nowIso, change_type: source };
  if (!device.connected) return { state: 3, timestamp, change_type: source };
  const modeMap: Record<number, "stimulate" | "deep" | "mix"> = {
    0: "stimulate",
    1: "deep",
    2: "mix",
  };
  return {
    state: device.pumpWorkState === 1 ? 1 : 0,
    scene: device.pumpScene === 1 ? "auto" : "manual",
    mode: typeof device.pumpMode === "number" ? modeMap[device.pumpMode] : undefined,
    level: typeof device.gear === "number" ? device.gear : undefined,
    timestamp,
    change_type: source,
  };
}

export function buildPumpAgentUploadWorkstateBodyFromDeviceStore(userId = DEFAULT_CHAT_USER_ID): PumpWorkstateBody {
  const store = deviceStore.get();
  return {
    user_id: userId,
    device_left: mapStoredDeviceToWorkstate(store.L, "L"),
    device_right: mapStoredDeviceToWorkstate(store.R, "R"),
  };
}

export function setPumpAgentUploadProcessSnapshot(side: DeviceSide, patch: Partial<PumpProcessSide>): void {
  const nowIso = new Date().toISOString();
  const sideSource = resolveSource(side);
  const deviceTs = deviceStore.get()[side]?.lastDeviceProcessTs;
  processSnapshotMap[side] = {
    ...processSnapshotMap[side],
    time: patch.time ?? (sideSource === "device" ? (deviceTs || nowIso) : nowIso),
    ...patch,
  };
}

function syncProcessSnapshotFromDeviceStore(): void {
  const store = deviceStore.get();
  const nowIso = new Date().toISOString();
  const leftSource = resolveSource("L");
  const rightSource = resolveSource("R");
  const nextL: PumpProcessSide = {
    ...processSnapshotMap.L,
    time: leftSource === "device" ? (store.L?.lastDeviceProcessTs || nowIso) : nowIso,
    cap_data: Math.max(
      0,
      Math.round((store.L?.flowFloat ?? processSnapshotMap.L.cap_data ?? 0) * 100) / 100,
    ),
    milk_reel: store.L ? composeMilkReelFromStore(store.L) : (processSnapshotMap.L.milk_reel ?? 0),
    bandpower: Math.max(0, Math.round(store.L?.bandpower ?? processSnapshotMap.L.bandpower ?? 0)),
    milk: Math.max(0, Math.round(store.L?.milkMl ?? processSnapshotMap.L.milk ?? 0)),
  };
  const nextR: PumpProcessSide = {
    ...processSnapshotMap.R,
    time: rightSource === "device" ? (store.R?.lastDeviceProcessTs || nowIso) : nowIso,
    cap_data: Math.max(
      0,
      Math.round((store.R?.flowFloat ?? processSnapshotMap.R.cap_data ?? 0) * 100) / 100,
    ),
    milk_reel: store.R ? composeMilkReelFromStore(store.R) : (processSnapshotMap.R.milk_reel ?? 0),
    bandpower: Math.max(0, Math.round(store.R?.bandpower ?? processSnapshotMap.R.bandpower ?? 0)),
    milk: Math.max(0, Math.round(store.R?.milkMl ?? processSnapshotMap.R.milk ?? 0)),
  };
  if (JSON.stringify(nextL) !== JSON.stringify(processSnapshotMap.L) || JSON.stringify(nextR) !== JSON.stringify(processSnapshotMap.R)) {
    processSnapshotMap.L = nextL;
    processSnapshotMap.R = nextR;
  }
}

function pushProcessFrameFromDeviceStore(): void {
  const store = deviceStore.get();
  for (const side of ["L", "R"] as const) {
    const current = store[side];
    const connected = Boolean(current?.connected);
    if (connected && !processPrevConnectedMap[side]) {
      processStepMap[side] = "stop";
      processStopMarkedMap[side] = false;
      processPauseMarkedMap[side] = false;
      processFrameMap[side] = [];
      processFrameLastTsMap[side] = "";
    }
    if (!connected && processPrevConnectedMap[side]) {
      processStepMap[side] = "stop";
      processPauseMarkedMap[side] = false;
      processFrameMap[side] = [];
      processFrameLastTsMap[side] = "";
    }
    processPrevConnectedMap[side] = connected;
    if (!connected || !current) continue;
    const ts = current.lastDeviceProcessTs || new Date().toISOString();
    // getPumpProcessData 采样不做去重：设备每次刷新都入队，按 1s 窗口自然截断为最近20帧。
    processFrameLastTsMap[side] = ts;
    const frameList = processFrameMap[side];
    const capData = Math.max(0, Math.round((current.flowFloat ?? 0) * 100) / 100);
    frameList.push({
      time: ts,
      cap_data: capData,
      milk_reel: composeMilkReelFromStore(current),
      bandpower: Math.max(0, Math.round(current.bandpower ?? 0)),
      milk: Math.max(0, Math.round(current.milkMl ?? 0)),
    });
    if (frameList.length > PROCESS_CAP_FRAME_SIZE) {
      frameList.splice(0, frameList.length - PROCESS_CAP_FRAME_SIZE);
    }
  }
}

function buildCapDataArray(side: "L" | "R"): number[] {
  const capDataList = processFrameMap[side].map((item) => item.cap_data);
  const needPadCount = Math.max(0, PROCESS_CAP_FRAME_SIZE - capDataList.length);
  const result = [...new Array(needPadCount).fill(0), ...capDataList].slice(-PROCESS_CAP_FRAME_SIZE);
  console.log("process cap_data window", {
    side,
    sampled_count: capDataList.length,
    padded_count: needPadCount,
    last_value: result[result.length - 1] ?? null,
  });
  return result;
}

function resolveProcessStep(side: "L" | "R", connected: boolean, running: boolean): PumpProcessStep {
  if (processStopMarkedMap[side]) {
    processStopMarkedMap[side] = false;
    processStepMap[side] = "stop";
    return "stop";
  }
  if (processPauseMarkedMap[side]) {
    processPauseMarkedMap[side] = false;
    processStepMap[side] = "pause";
    return "pause";
  }
  if (!connected) {
    processStepMap[side] = "stop";
    return "stop";
  }
  if (!running) {
    const prevStep = processStepMap[side];
    if (prevStep === "running" || prevStep === "start" || prevStep === "pause") {
      processStepMap[side] = "pause";
      return "pause";
    }
    processStepMap[side] = "stop";
    return "stop";
  }
  const prevStep = processStepMap[side];
  const nextStep: PumpProcessStep = prevStep === "stop" ? "start" : "running";
  processStepMap[side] = nextStep;
  return nextStep;
}

function buildProcessDataSide(side: "L" | "R", storeItem: StoredDeviceInfo | null): PumpProcessDataSide {
  const nowIso = new Date().toISOString();
  const connected = Boolean(storeItem?.connected);
  const running = connected && storeItem?.pumpWorkState === 1;
  if (!connected) {
    resolveProcessStep(side, false, false);
    return {
      step: "offline",
      cap_data: new Array(PROCESS_CAP_FRAME_SIZE).fill(0),
      time: nowIso,
      milk_reel: 0,
      bandpower: 0,
      milk: 0,
    };
  }
  if (!running) {
    return {
      step: resolveProcessStep(side, true, false),
      cap_data: new Array(PROCESS_CAP_FRAME_SIZE).fill(0),
      time: storeItem?.lastDeviceProcessTs || nowIso,
      milk_reel: 0,
      bandpower: 0,
      milk: 0,
    };
  }
  const frameList = processFrameMap[side];
  const lastFrame = frameList[frameList.length - 1];
  return {
    step: resolveProcessStep(side, true, true),
    cap_data: buildCapDataArray(side),
    time: lastFrame?.time || storeItem?.lastDeviceProcessTs || nowIso,
    milk_reel: lastFrame?.milk_reel ?? 0,
    bandpower: lastFrame?.bandpower ?? 0,
    milk: lastFrame?.milk ?? 0,
  };
}

function buildProcessDataBody(userId = DEFAULT_CHAT_USER_ID): PumpProcessDataBody {
  const store = deviceStore.get();
  return {
    user_id: userId,
    device_left: buildProcessDataSide("L", store.L),
    device_right: buildProcessDataSide("R", store.R),
  };
}

function hasAnyDeviceRunning(): boolean {
  const store = deviceStore.get();
  const leftRunning = Boolean(store.L?.connected && store.L?.pumpWorkState === 1);
  const rightRunning = Boolean(store.R?.connected && store.R?.pumpWorkState === 1);
  return leftRunning || rightRunning;
}

function hasAnyPendingStopStep(): boolean {
  return processStopMarkedMap.L || processStopMarkedMap.R;
}

function hasAnyPendingPauseStep(): boolean {
  return processPauseMarkedMap.L || processPauseMarkedMap.R;
}

async function getProcessDataIfNeeded(): Promise<void> {
  if ((!hasAnyDeviceRunning() && !hasAnyPendingStopStep() && !hasAnyPendingPauseStep()) || processDataFetching) return;
  processDataFetching = true;
  try {
    console.log("get pump process data tick", {
      queue_l: processFrameMap.L.length,
      queue_r: processFrameMap.R.length,
      last_ts_l: processFrameLastTsMap.L || null,
      last_ts_r: processFrameLastTsMap.R || null,
    });
    const body = buildProcessDataBody();
    console.log("get pump process data", body);
    const response = await getPumpProcessData(body);
    if (!response || typeof response !== "object") {
      console.warn("get pump process data invalid response object", { response });
      return;
    }
    const responseData = response as { error?: unknown; process_l?: unknown; process_r?: unknown; process_all?: unknown };
    const rawProcessL = Number(responseData.process_l ?? 0);
    const rawProcessR = Number(responseData.process_r ?? 0);
    const rawProcessAll = Number(responseData.process_all ?? 0);
    const processError = Number(responseData.error ?? 0);
    if (processError !== 0) {
      console.warn("get pump process data error, keep previous progress", {
        process_error: processError,
        raw_process_l: responseData.process_l,
        raw_process_r: responseData.process_r,
        raw_process_all: responseData.process_all,
      });
      return;
    }
    if (Number.isNaN(rawProcessL) || Number.isNaN(rawProcessR) || Number.isNaN(rawProcessAll)) {
      console.warn("get pump process data invalid process value", {
        raw_process_l: responseData.process_l,
        raw_process_r: responseData.process_r,
        raw_process_all: responseData.process_all,
        response,
      });
      return;
    }
    const shouldUpdateLeft = body.device_left.step !== "stop";
    const shouldUpdateRight = body.device_right.step !== "stop";
    if (shouldUpdateLeft) {
      processProgressMap.L = Math.max(0, Math.round(rawProcessL));
    }
    if (shouldUpdateRight) {
      processProgressMap.R = Math.max(0, Math.round(rawProcessR));
    }
    processProgressAll = Math.max(0, Math.round(rawProcessAll));
    processSnapshotMap.L = { ...processSnapshotMap.L, process: processProgressMap.L };
    processSnapshotMap.R = { ...processSnapshotMap.R, process: processProgressMap.R };
    // console.log("get pump process data progress mapped", {
    //   raw_process_l: rawProcessL,
    //   raw_process_r: rawProcessR,
    //   raw_process_all: rawProcessAll,
    //   mapped_process_l: processProgressMap.L,
    //   mapped_process_r: processProgressMap.R,
    //   mapped_process_all: processProgressAll,
    // });
    emitPumpAgentUploadProcessProgress();
    console.log("get pump process data response summary", {
      api_error: (response as { error?: unknown })?.error ?? null,
      process_error: processError,
      request_step_l: body.device_left.step,
      request_step_r: body.device_right.step,
      should_update_l: shouldUpdateLeft,
      should_update_r: shouldUpdateRight,
      raw_process_l: rawProcessL,
      raw_process_r: rawProcessR,
      raw_process_all: rawProcessAll,
      process_l: processProgressMap.L,
      process_r: processProgressMap.R,
      process_all: processProgressAll,
    });
    processFrameMap.L = [];
    processFrameMap.R = [];
    processFrameLastTsMap.L = "";
    processFrameLastTsMap.R = "";
    console.log("get pump process data tick done, frame buffers cleared");
  } catch (error) {
    console.warn("get pump process data failed", error);
  } finally {
    processDataFetching = false;
  }
}

function hasAnyDeviceConnected(): boolean {
  const store = deviceStore.get();
  return Boolean(store.L?.connected || store.R?.connected);
}

function buildWorkstateSignature(): string {
  const store = deviceStore.get();
  const left = store.L;
  const right = store.R;
  return JSON.stringify({
    L: {
      connected: Boolean(left?.connected),
      pumpWorkState: left?.pumpWorkState ?? null,
      pumpScene: left?.pumpScene ?? null,
      pumpMode: left?.pumpMode ?? null,
      gear: left?.gear ?? null,
    },
    R: {
      connected: Boolean(right?.connected),
      pumpWorkState: right?.pumpWorkState ?? null,
      pumpScene: right?.pumpScene ?? null,
      pumpMode: right?.pumpMode ?? null,
      gear: right?.gear ?? null,
    },
  });
}

function buildProcessBody(userId = DEFAULT_CHAT_USER_ID): PumpProcessBody {
  const nowIso = new Date().toISOString();
  const store = deviceStore.get();
  const zeroSide = (snapshot: PumpProcessSide): PumpProcessSide => ({
    ...snapshot,
    time: snapshot.time || nowIso,
    process: 0,
    cap_data: 0,
    milk_reel: 0,
    bandpower: 0,
    milk: 0,
  });
  return {
    user_id: userId,
    process_left: store.L?.connected
      ? { ...processSnapshotMap.L, time: processSnapshotMap.L.time || nowIso }
      : zeroSide(processSnapshotMap.L),
    process_right: store.R?.connected
      ? { ...processSnapshotMap.R, time: processSnapshotMap.R.time || nowIso }
      : zeroSide(processSnapshotMap.R),
  };
}

async function uploadWorkstateIfChanged(): Promise<void> {
  if (!hasAnyDeviceConnected() || workstateUploading) return;
  const signature = buildWorkstateSignature();
  if (signature === workstateSignature) return;
  workstateUploading = true;
  try {
    const body = buildPumpAgentUploadWorkstateBodyFromDeviceStore();
    console.log("upload workstate", body);
    await uploadPumpWorkstate(body);
    workstateSignature = signature;
  } catch (err) {
    console.warn("upload workstate failed", err);
  } finally {
    workstateUploading = false;
  }
}

async function uploadProcessIfNeeded(): Promise<void> {
  if (!hasAnyDeviceConnected() || processUploading) return;
  const body = buildProcessBody();
  processUploading = true;
  try {
    console.log("upload process", body);
    const response = await uploadPumpProcess(body);
    const text = typeof response.output === "string" ? response.output.trim() : "";
    const richText = normalizePumpAgentUploadDirectRichText(response.direct_rich_text);
    const buttons = (richText?.button ?? []).filter((btn) => Boolean(btn.text || btn.value));
    const shouldEmitReply = Boolean(response.need_reply) && (Boolean(text) || buttons.length > 0);
    console.log("upload process reply decision", {
      need_reply: response.need_reply ?? null,
      has_output_text: Boolean(text),
      button_count: buttons.length,
      should_emit_reply: shouldEmitReply,
    });
    if (shouldEmitReply) emitPumpProcessReply(text, buttons);
  } catch (err) {
    console.warn("upload process failed", err);
  } finally {
    processUploading = false;
  }
}

export function startPumpAgentUploadService(): void {
  if (started) return;
  started = true;
  syncProcessSnapshotFromDeviceStore();
  pushProcessFrameFromDeviceStore();
  unsubscribeDeviceStore = deviceStore.subscribe(() => {
    syncProcessSnapshotFromDeviceStore();
    pushProcessFrameFromDeviceStore();
    void uploadWorkstateIfChanged();
  });
  processTimer = window.setInterval(() => {
    void uploadProcessIfNeeded();
  }, PROCESS_UPLOAD_INTERVAL_MS);
  processDataTimer = window.setInterval(() => {
    void getProcessDataIfNeeded();
  }, PROCESS_DATA_INTERVAL_MS);
  void uploadWorkstateIfChanged();
  void getProcessDataIfNeeded();
}

export function stopPumpAgentUploadService(): void {
  if (!started) return;
  started = false;
  unsubscribeDeviceStore?.();
  unsubscribeDeviceStore = null;
  if (processTimer != null) {
    window.clearInterval(processTimer);
    processTimer = null;
  }
  if (processDataTimer != null) {
    window.clearInterval(processDataTimer);
    processDataTimer = null;
  }
}
