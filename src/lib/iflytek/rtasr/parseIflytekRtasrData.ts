/**
 * 讯飞 RTASR WebSocket 返回：`action=result` 时 `data` 为 **JSON 字符串**，需 `JSON.parse` 得到内层对象。
 *
 * ## 外层（WebSocket 文本帧）
 * `{ "action":"result"|"started"|"error", "code":"0", "data":"...", "desc":"...", "sid":"..." }`
 *
 * ## 内层 `data` parse 后（与你的日志、标准版示例一致）
 * - **`seg_id`**：与 **`cn` 同级**（根上），结果包序号，从 0 递增；大模型版文档也称「返回消息号」。
 * - **`ls`**：大模型版文档写明——**是否为转写最后一帧**：`true` 表示本条为收尾相关结果；你发送 `end` 后 `type=0` 且 `ls=true` 即整段定稿。
 * - **`cn.st.type`**：`0` = 最终结果，`1` = 中间结果（标准版文档）。
 * - **`cn.st.bg` / `cn.st.ed`**：本段在整段语音中的起止时间（ms），日志里为字符串。
 * - **`cn.st.rt`**：数组；元素含 **`ws`**（词序列）。
 * - **`ws[]`**：分词单元；含 **`cw`** 及可选 `wb`/`we`。
 * - **`cw[]`**：字/词；**`w`** 为文本，**`wp`**：`n` 普通词、`s` 顺滑、`p` 标点；实测还有 `sc`、`wc`、`rl` 等，拼接正文时只取 `w` 即可。
 *
 * ## 流式语义（结合你提供的 seg0～8 全为 type=1、seg9 为 type=0+ls=true）
 * - 递增 `seg_id` 且 **`type=1`** 的多包，常是**同一句的滚动累计**（后包文本变长、内容覆盖前包），**不能**把各 `seg_id` 的草稿字符串再首尾相接。
 * - **定稿**以 **`type=0`** 为准；若已收到 final，合并时不应再把仅含中间结果的低 `seg_id` 槽拼进提交文本。
 *
 * 参考：
 * - 标准版：https://www.xfyun.cn/doc/asr/rtasr/API.html
 * - 大模型版（含 `ls`）：https://www.xfyun.cn/doc/spark/asr_llm/rtasr_llm.html
 */

/** 单个 seg_id 对应的展示/定稿状态 */
export type IflytekRtasrSegSlot = {
  /** type=0 的最终结果；存在后该段不再被 type=1 覆盖 */
  finalText: string | null;
  /** 尚无 final 时的中间稿（type=1），或已与 final 同步 */
  draftText: string;
};

/**
 * 解析单条 RTASR `data` JSON 字符串。
 * @param dataStr 外层消息里的 `data`（JSON 字符串）
 * @returns segId、是否最终结果、正文、`ls` 是否最后一帧；无法解析或非转写 cn 结构时返回 null
 */
export function parseIflytekRtasrDataPayload(dataStr: string): {
  segId: number;
  isFinal: boolean;
  /** 大模型文档：ls=true 表示最后一帧（收尾定稿） */
  isLastFrame: boolean;
  text: string;
} | null {
  try {
    const root = JSON.parse(dataStr) as Record<string, unknown>;
    if (root.biz === "trans") {
      return null;
    }
    const cn = root.cn as Record<string, unknown> | undefined;
    if (!cn?.st) return null;
    const st = cn.st as Record<string, unknown>;
    const rawSeg =
      (root as { seg_id?: unknown }).seg_id ?? (cn as { seg_id?: unknown }).seg_id;
    const segId =
      typeof rawSeg === "number"
        ? rawSeg
        : typeof rawSeg === "string"
          ? parseInt(rawSeg, 10)
          : 0;
    const typeRaw = st.type;
    const isFinal = typeRaw === "0" || typeRaw === 0;
    const rawLs = (root as { ls?: unknown }).ls;
    const isLastFrame = rawLs === true || rawLs === "true";
    const rt = st.rt as unknown[] | undefined;
    if (!Array.isArray(rt) || rt.length === 0) {
      return { segId, isFinal, isLastFrame, text: "" };
    }
    let text = "";
    for (const rtItem of rt) {
      const wsArr = (rtItem as Record<string, unknown>).ws as unknown[] | undefined;
      if (!Array.isArray(wsArr)) continue;
      for (const ws of wsArr) {
        const wso = ws as Record<string, unknown>;
        const cwArr = wso.cw as unknown[] | undefined;
        if (!Array.isArray(cwArr)) continue;
        for (const cw of cwArr) {
          const w = (cw as Record<string, unknown>).w;
          if (typeof w === "string") text += w;
        }
      }
    }
    return { segId, isFinal, isLastFrame, text };
  } catch {
    return null;
  }
}

/**
 * 将一条解析结果写入分槽。
 * @param slots seg_id → 槽
 * @param segId 包序号
 * @param isFinal 是否 type=0
 * @param text 本包拼接出的正文
 */
export function applyIflytekRtasrSegmentUpdate(
  slots: Map<number, IflytekRtasrSegSlot>,
  segId: number,
  isFinal: boolean,
  text: string,
): void {
  if (isFinal) {
    slots.set(segId, { finalText: text, draftText: text });
    return;
  }
  const prev = slots.get(segId);
  if (prev?.finalText != null) {
    return;
  }
  slots.set(segId, { finalText: null, draftText: text });
}

/**
 * 合并各槽为一条展示/提交用全文（对齐实测流式协议，避免「床前床前…」式叠字）。
 *
 * 规则：
 * 1. 若**存在任意** `finalText`：只按 `seg_id` 升序**串联含 final 的槽**（跳过仅中间稿的低 seg）；再若存在 **大于「最后一条 final 的 seg_id」** 的槽（下一句正在识别），追加其中 **最大 seg_id** 的 `draftText`。
 * 2. 若**尚无任何** final（仍在说、未收口）：**只取最大 `seg_id` 的 draft**（同句滚动累计，避免多 seg 拼接）。
 *
 * @param slots 各 seg 状态
 * @returns 合并正文
 */
export function mergeIflytekRtasrSlots(slots: Map<number, IflytekRtasrSegSlot>): string {
  const ids = [...slots.keys()].sort((a, b) => a - b);
  if (ids.length === 0) return "";

  const idsWithFinal = ids.filter((id) => slots.get(id)?.finalText != null);
  if (idsWithFinal.length === 0) {
    const maxId = ids[ids.length - 1]!;
    return slots.get(maxId)!.draftText.trim();
  }

  const lastFinalId = idsWithFinal[idsWithFinal.length - 1]!;
  const parts: string[] = [];
  for (const id of ids) {
    if (id > lastFinalId) break;
    const s = slots.get(id)!;
    const f = s.finalText?.trim();
    if (f) parts.push(f);
  }

  const tailIds = ids.filter((id) => id > lastFinalId);
  if (tailIds.length > 0) {
    const maxTail = Math.max(...tailIds);
    const tail = slots.get(maxTail)!.draftText.trim();
    if (tail) parts.push(tail);
  }

  return parts.join("");
}
