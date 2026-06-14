import type { MediaVoiceNarrationItem } from "@/lib/mediaVoiceNarration";

/**
 * 与《API接口说明文档》V1.3 对齐的请求/响应类型（字段待补充处用可选字段兼容）。
 */

/** 多数接口 data 内业务结果码：0 成功，-1 失败 */
export type ApiErrorCode = 0 | -1;

// ─── 通用 ──────────────────────────────────────────────────────────

export interface FileUploadResponseData {
  id: string;
  name: string;
  size: number;
  extension: string;
  mime_type: string;
}

export interface UserProfileData {
  error: ApiErrorCode;
  user_id: string;
  display_name?: string;
  age?: number | null;
  profile_onboarding_complete?: boolean;
  profile_onboarding_skipped?: boolean;
  profile_onboarding_skipped_at?: string;
  profile_onboarding_completed_at?: string;
  birth_prep_due_date_or_week?: string;
  birth_prep_birth_path?: string;
  birth_prep_support_person?: string;
}

// ─── 对话 ────────────────────────────────────────────────────────────

export interface ChatMessageBody {
  agent: string;
  /** 传给 Agent 的结构化参数 */
  input?: Record<string, unknown>;
  query: string;
  response_mode: "streaming" | "blocking";
  /** 首次对话传空字符串；收到服务端返回的 conversation_id 后由客户端写入后续请求 */
  conversation_id: string;
  user: string;
  /** 上传文件列表；文档要求 array[object]，历史实现兼容 object */
  files:
    | Array<{
        type: "image";
        transfer_method: "local_file";
        upload_file_id: string;
      }>
    | Record<string, unknown>;
  /** 记忆相关参数（JSON object），文档为选填、调试用 */
  memory_immit?: Record<string, unknown>;
}

/** chat-message SSE 中 rich_text 内单颗按钮 */
export interface ChatRichTextButtonItem {
  text: string;
  value: string;
  /** 如 answer、link 等，由服务端定义 */
  type: string;
  highlight: boolean;
  icon: string;
}

/** chat-message SSE 中 rich_text 内卡片条目内容 */
export interface ChatRichTextCardContentItem {
  title: string;
  content: string;
}

/** chat-message SSE 中 rich_text 内卡片 */
export interface ChatRichTextCardItem {
  text: string;
  type: string;
  highlight: boolean;
  content: ChatRichTextCardContentItem[];
}

/**
 * chat-message SSE 推送的富文本结构（event: rich_text 时置于 rich_text 字段）。
 * action 预留扩展，结构未定时用 unknown[] 兼容。
 */
export interface ChatRichTextPayload {
  title: string;
  content: string;
  button: ChatRichTextButtonItem[];
  card: ChatRichTextCardItem[];
  action: unknown[];
  /** 可选的媒体语音播报元数据；只有显式提供 spokenLabel 且策略允许时才会进入 TTS。 */
  voice?: MediaVoiceNarrationItem[];
}

/** chat-messages SSE 的 data 中 action_content（字符串 JSON 或对象） */
export interface ChatActionContentPayload {
  /** 如 add level / dec level */
  val: string;
  /** both / left / right */
  target_scope: string;
  /** add level / dec level 时一次增减的档位数，缺省按 1 */
  level?: number;
}

/** 对话打断（V1.2）：POST `/v1/workflows/tasks/{conversation_id}/stop`，仅 Body 携带 user_id */
export interface WorkflowStopBody {
  user_id: string;
}

export interface WorkflowStopData {
  error: ApiErrorCode;
}

export interface ChatHistoryParams {
  user_id: string;
  conversation_id: string;
  count: number;
}

/** 历史接口 data 结构文档待补充 */
export type ChatHistoryData = Record<string, unknown>;

// ─── 吸乳 pump ───────────────────────────────────────────────────────

export interface PumpThresholdUploadBody {
  user_id: string;
  stimulate_level_l: number;
  deep_level_l: number;
  stimulate_level_r: number;
  deep_level_r: number;
}

export interface PumpThresholdData {
  error: ApiErrorCode;
  stimulate_level_l?: number;
  deep_level_l?: number;
  stimulate_level_r?: number;
  deep_level_r?: number;
}

/** GET `/v1/pump/energy/get` 乳势能释放目标查询响应 */
export interface PumpEnergyTargetData {
  error: ApiErrorCode;
  upper_value?: number;
  lower_value?: number;
}

export interface PumpDeviceState {
  /** 设备的工作状态：0 暂停中，1 正在运行，2 关机，3 离线，4 未配对 */
  state: number;
  /** 设备的工作场景：auto 自动，manual 手动 */
  scene?: string;
  /** 设备的工作模式：stimulate 刺激，deep 深度，mix 混合 */
  mode?: string;
  /** 设备的工作档位 */
  level?: number;
  /** 吸乳进程的百分比 */
  process?: number;
  /** 设备状态切换时的时间 */
  timestamp?: string;
  /** 设备工作状态改变的原因：app 从app端调节，agent 从agent端下发修改，device 从设备端修改 */
  change_type?: string;
}

export interface PumpWorkstateBody {
  user_id: string;
  device_left: PumpDeviceState;
  device_right: PumpDeviceState;
}

/** uploadPumpWorkstate 响应 data */
export interface UploadPumpWorkstateResponseData {
  /** 请求执行结果：0 成功，-1 失败 */
  error: number;
  /** 是否需要展示智能体回复 */
  need_reply: boolean;
  /** 智能体回复文本 */
  output: string;
  /** 标识回复触发原因 */
  reply_code?: string;
  /** 标识回复触发侧 */
  reply_side?: string;
  /** 按钮富文本（结构由后端定义，前端按需解析） */
  direct_rich_text?: Record<string, unknown>;
}

/** uploadPumpWorkstate 响应（经 apiRequest 解包后为 data 顶层字段） */
export type UploadPumpWorkstateResponse = UploadPumpWorkstateResponseData;

export interface PumpProcessSide {
  /** 进程数据采样时间（UTC 时间字符串） */
  time: string;
  process: number;
  cap_data: number;
  milk_reel: number;
  bandpower: number;
  milk: number;
}

export interface PumpProcessBody {
  user_id: string;
  process_left: PumpProcessSide;
  process_right: PumpProcessSide;
}

/** uploadPumpProcess 响应 data */
export interface UploadPumpProcessResponseData {
  /** 请求执行结果：0 成功，-1 失败 */
  error: number;
  /** 是否需要展示智能体回复 */
  need_reply: boolean;
  /** 智能体回复文本 */
  output: string;
  /** 标识回复触发原因 */
  reply_code?: string;
  /** 标识回复触发侧 */
  reply_side?: string;
  /** 按钮富文本（结构由后端定义，前端按需解析） */
  direct_rich_text?: Record<string, unknown>;
}

/** 获取设备吸乳进程时，单侧设备上传的数据 */
export interface PumpProcessDataSide {
  /** start / running / pause / stop */
  step: string;
  /** 奶阵电容数组 */
  cap_data: number[];
  /** 吸奶时间（UTC 字符串） */
  time: string;
  /** 吸乳通道标记 */
  milk_reel: number;
  /** 归一化后的 bandpower 值 */
  bandpower: number;
  /** 当前奶量 */
  milk: number;
}

/** POST `/v1/pump/process/data` 请求体 */
export interface PumpProcessDataBody {
  user_id: string;
  device_left: PumpProcessDataSide;
  device_right: PumpProcessDataSide;
}

/** 获取设备吸乳进程接口的 data */
export interface PumpProcessDataResponseData {
  /** 请求执行结果：0 成功，-1 失败 */
  error: ApiErrorCode;
  /** 进程计算失败时的原因 */
  text: string;
  /** 左侧设备吸乳进程 */
  process_l: number;
  /** 右侧设备吸乳进程 */
  process_r: number;
  /** 左右综合的吸乳进程 */
  process_all: number;
}

export interface PumpSessionSummarySide {
  connected?: boolean;
  milk_ml?: number;
  process?: number;
  mode?: string;
  level?: number;
  duration_seconds?: number;
  has_milk?: boolean;
  has_letdown?: boolean;
  /** 本次吸乳该侧检测到的奶阵触发次数 */
  letdown_count?: number;
}

export interface PumpSessionSummaryBody {
  user_id: string;
  conversation_id: string;
  ended_at?: string;
  started_at?: string;
  end_reason?: string;
  process_all?: number;
  total_milk_ml?: number;
  duration_seconds?: number;
  event_id?: string;
  left?: PumpSessionSummarySide;
  right?: PumpSessionSummarySide;
}

export interface PumpSessionSummaryChatMessage {
  id?: string;
  role?: "mai" | "user" | string;
  content?: string;
  timestamp?: string;
  cardType?: string;
  cardData?: Record<string, unknown>;
}

export interface PumpSessionSummaryData {
  error?: number;
  message?: string;
  session?: Record<string, unknown>;
  chat_message?: PumpSessionSummaryChatMessage;
  context?: Record<string, unknown>;
}

export interface PumpSessionSummaryResponse {
  status?: number;
  message?: string;
  data?: PumpSessionSummaryData;
}

/** 妈妈吸乳信息查询 data.lactation_info_list 单日项（V1.2） */
export interface PumpInfoLactationDayItem {
  total_milk: number;
  /** 文档字段名为 total_milk_estimate（协议原样） */
  total_milk_estimate: number;
  /** 兼容历史/错误拼写字段 */
  totol_milk_estimate?: number;
  reference_upper: number;
  reference_lower: number;
  delivery_date: string;
}

/** GET /v1/pump/info/get 的 data（V1.2；delivery_tage 为文档字段名） */
export interface PumpInfoData {
  error: ApiErrorCode;
  delivery_week?: number;
  delivery_tage?: string;
  lactation_advice?: string;
  target_progress?: number;
  lactation_info_list?: PumpInfoLactationDayItem[];
}

export interface MomBabyInfoParams {
  user_id: string;
}

export interface MomBabyInfoData {
  error: ApiErrorCode;
  delivery_date: string;
  deliveryDate?: string;
  deliverydate?: string;
  lactation_advice: string;
  feeding_advice: string;
}

export interface MomBabyTodayParams {
  user_id: string;
}

export interface MomBabyTodayData {
  error: ApiErrorCode;
  pump_milk_volum: number;
  feeding_volum: number;
  feeding_forecast_volum: number;
}

// ─── 宝宝与喂养 ─────────────────────────────────────────────────────

export interface BabyInfoCreateBody {
  user_id: string;
  birth_date: string;
  sex: string;
  name?: string;
}

export interface BabyInfoCreateData {
  error: ApiErrorCode;
  infant_id: number;
}

export interface BabyInfoItem {
  infant_id?: number;
  birth_date: string;
  sex: string;
  growth_status: string;
  name?: string;
}

export interface BabyInfoQueryData {
  error: ApiErrorCode;
  baby_info_list?: BabyInfoItem[];
}

export interface FeedingAddBody {
  user_id: string;
  feed_type: number;
  feed_action: number;
  feed_time: string;
  /** 客户端补充：由任务触发时透传喂养标题 */
  feeding_title?: string;
  /** 文档字段名 feed_milk_volum */
  feed_milk_volum: number;
}

export interface FeedingAddData {
  error: ApiErrorCode;
  feeding_id: number;
}

export interface FeedingDeleteBody {
  user_id: string;
  feeding_id: number;
}

export interface FeedingDeleteData {
  error: ApiErrorCode;
}

export interface FeedingQueryParams {
  user_id: string;
  timestamp?: string;
}

export interface FeedingListItem {
  feeding_id: number;
  infant_id: number;
  feed_type: number;
  feed_action: number;
  feed_time: string;
  /** 客户端补充：服务端若回传喂养标题则用于记录展示 */
  feeding_title?: string;
  title?: string;
  feed_milk_volum?: number;
  /** 亲喂时长（分钟）；部分历史数据可能缺失 */
  feed_duration?: number;
}

export interface FeedingQueryData {
  error: ApiErrorCode;
  total_feed: number;
  feed_list: FeedingListItem[];
}

// ─── 生长发育 growth ─────────────────────────────────────────────────

export interface GrowthAddBody {
  user_id: string;
  height_cm: number;
  weight_kg: number;
  head_cm: number;
}

export interface GrowthAddData {
  error: ApiErrorCode;
  growth_id: number;
}

export interface GrowthQueryParams {
  user_id: string;
}

export interface GrowthRecord {
  growth_id: number;
  /** 生长记录日期（YYYY-MM-DD），历史曲线以此字段作为横轴时间基准 */
  date: string;
  height_cm: number;
  weight_kg: number;
  head_cm: number;
  /** 身高测量时间（历史曲线身长轴锚点；缺省时由映射层兜底） */
  height_mes_time?: string;
  /** 体重测量时间（历史曲线体重轴锚点） */
  weight_mes_time?: string;
  /** 头围测量时间 */
  head_mes_time?: string;
}

export interface GrowthQueryData {
  error: ApiErrorCode;
  growth_id: number;
  height_cm: number;
  weight_kg: number;
  head_cm: number;
  /** 最近一次记录由后台生成，前端展示数值即可 */
  height_mes_time?: string;
  weight_mes_time?: string;
  head_mes_time?: string;
}

export interface GrowthReviseBody {
  user_id: string;
  growth_id: number;
  height_cm?: number;
  weight_kg?: number;
  head_cm?: number;
}

export interface GrowthReviseData {
  error: ApiErrorCode;
  growth_id: number;
}

export interface GrowthHistoryParams {
  user_id: string;
}

export interface GrowthHistoryData {
  error: ApiErrorCode;
  growth_data: GrowthRecord[];
}

// ─── 计划 plan ───────────────────────────────────────────────────────

export interface PlanQueryParams {
  user_id: string;
  timestamp: string;
}

/**
 * 呵护计划中单个 milestone 阶段（文档 milestones_list 项；标题字段文档为 titile）。
 */
export interface PlanMilestoneListItem {
  /** 文档字段名 titile（常见为 title 笔误）；若服务端改为 title 可同时存在 */
  titile?: string;
  title?: string;
  date: string;
  duration_weeks: number;
  content: string;
}

/**
 * 呵护计划 plan_list 中单条计划（含里程碑列表与进展概括）。
 */
export interface PlanListItem {
  plan_name: string;
  milestones_summary: string;
  milestones_list: PlanMilestoneListItem[];
}

/**
 * 查询呵护计划详细任务内容接口返回的 data（GET `/v1/plan/query-task`）。
 */
export interface PlanQueryData {
  error: ApiErrorCode;
  /** maintain / chase / wean / fertility / work，与文档一致；未列出的值按 string 透传 */
  plan_type: string;
  task_list: PlanTaskItem[];
}

export interface CarePlanArtifact {
  plan_id: number;
  user_id: string;
  plan_type: string;
  title: string;
  summary: string;
  status: string;
  source_artifact_type?: string;
  created_at: string;
  updated_at: string;
  payload: Record<string, unknown>;
}

export interface PlanListData {
  error: ApiErrorCode;
  plan_list: CarePlanArtifact[];
}

export interface PlanDetailData {
  error: ApiErrorCode;
  plan: CarePlanArtifact | null;
}

export interface PlanArtifactDeleteBody {
  user_id: string;
  plan_id: number;
}

export interface PlanArtifactDeleteData {
  error: ApiErrorCode;
}

export interface PregnancyDiaryEntry {
  entry_id: number;
  user_id: string;
  entry_date: string;
  gestational_week: string;
  mood: string;
  energy_level: string;
  sleep_summary: string;
  fetal_movement: string;
  symptom_tags: string[];
  appointment_note: string;
  nutrition_note: string;
  content: string;
  attachments: Record<string, unknown>[];
  created_at: string;
  updated_at: string;
}

export interface PregnancyDiaryListData {
  error: ApiErrorCode;
  diary_list: PregnancyDiaryEntry[];
}

export interface PregnancyDiaryEntryData {
  error: ApiErrorCode;
  diary: PregnancyDiaryEntry | null;
}

export interface PregnancyDiaryCreateBody {
  user_id: string;
  entry_date: string;
  gestational_week?: string;
  mood?: string;
  energy_level?: string;
  sleep_summary?: string;
  fetal_movement?: string;
  symptom_tags?: string[];
  appointment_note?: string;
  nutrition_note?: string;
  content?: string;
  attachments?: Record<string, unknown>[];
}

export interface PregnancyDiaryUpdateBody extends PregnancyDiaryCreateBody {
  entry_id: number;
}

export interface PregnancyDiaryDeleteBody {
  user_id: string;
  entry_id: number;
}

/** V1.3 呵护计划任务条目 */
export interface PlanTaskItem {
  task_id: number;
  task_time: string;
  task_content: string;
  task_type: number;
  task_source: string;
  task_done: string;
}

export interface PlanTaskInputItem {
  task_time: string;
  task_content: string;
  task_type: number;
  task_source: string;
}

export interface AddPlanTaskBody {
  user_id: string;
  timestamp: string;
  task_list: PlanTaskInputItem[];
}

export interface DeletePlanTaskBody {
  user_id: string;
  timestamp: string;
  task_id: number;
}

export interface RevisePlanTaskBody {
  user_id: string;
  task_id: number;
  timestamp: string;
  task_time: string;
  task_content: string;
  task_done: string;
}

export interface PlanTaskMutationData {
  error: ApiErrorCode;
  task_list: PlanTaskItem[];
}

export interface PlanPumpTodayParams {
  user_id: string;
  timestamp: string;
}

/**
 * plan-pump/today 的 plan_list 单项；避开时段已合并进列表，勿再解析 plan_data.avoid_periods。
 */
export interface PlanPumpListEntry {
  /** plan：排乳/亲喂等；avoid：避开时段（展示为日程类，不参与本地顺延计算） */
  entry_type?: string;
  time: string;
  content: string;
  finish: boolean;
  label?: string;
  start_time?: string;
  end_time?: string;
  plan_id?: number;
}

export interface PlanPumpTodayData {
  error: ApiErrorCode;
  plan_data: {
    plan_id: number;
    plan_name?: string | number;
    plan_list: PlanPumpListEntry[];
    /** 服务端可能返回；内容已并入 plan_list，前端不得再解析或合并 */
    avoid_periods?: unknown;
  };
}

/** GET `/v1/plan/milk_period` 查询参数 */
export interface PlanMilkPeriodParams {
  user_id: string;
}

/**
 * 泌乳周期各阶段开始时间（响应 data.milk_period，与文档字段一致）。
 * 各字段一般为日期/时间字符串，格式由服务端约定。
 */
export interface MilkPeriodInfo {
  colostrum_period: string;
  establishment_period: string;
  stable_delivery_period: string;
  weaning_period: string;
}

/** 查询妈妈泌乳周期接口返回的 data 体 */
export interface PlanMilkPeriodData {
  error: ApiErrorCode;
  milk_period: MilkPeriodInfo;
}

export interface PlanPumpPeriodBody {
  user_id: string;
  plan_id?: number;
  /** 避开时段说明（V1.2 add-period 可选） */
  content?: string;
  start_time: string;
  end_time: string;
}

// ─── 背奶 pump-milk ─────────────────────────────────────────────────

export interface PumpMilkUploadBody {
  user_id: string;
  /** V1.2：0 吸奶器上报 / 1 补录 / 2 亲喂 */
  pump_type: number;
  /** V1.3：0 设备 / 1 手动 / 2 计划 */
  pump_source: number;
  pump_time: string;
  /** 客户端补充：由任务触发时透传吸奶标题 */
  pump_title?: string;
  pump_milk_volum?: number;
}

export interface PumpMilkUploadData {
  error: ApiErrorCode;
  /** V1.2：新增记录成功后返回的唯一 Id */
  pump_id?: number;
}

/** POST /v1/pump-milk/delete 请求体（V1.2） */
export interface PumpMilkDeleteBody {
  user_id: string;
  pump_id: number;
}

export interface PumpMilkDeleteData {
  error: ApiErrorCode;
}

export interface PumpMilkQueryParams {
  user_id: string;
  timestamp?: string;
}

/** GET /v1/pump-milk/query 列表项（文档中 pump_type 为 integer） */
export interface PumpMilkListItem {
  pump_id: number;
  pump_type: number;
  pump_source: number;
  pump_time: string;
  /** 客户端补充：服务端若回传吸奶标题则用于记录展示 */
  pump_title?: string;
  title?: string;
  pump_milk_volum: number;
}

export interface PumpMilkQueryData {
  error: ApiErrorCode;
  pump_milk_list: PumpMilkListItem[];
}

// ─── 设备 ────────────────────────────────────────────────────────────

export interface DeviceConnectionSide {
  model: string;
  state: string;
  battery: number;
  sn: string;
  rssi: number;
  version: string;
}

export interface DeviceInfoBody {
  user_id: string;
  device_left: DeviceConnectionSide;
  device_right: DeviceConnectionSide;
}

export interface DeviceInfoData {
  error: ApiErrorCode;
}

// ─── 系统级后台任务 ─────────────────────────────────────────────────

export interface NotifyQueryParams {
  user_id: string;
  timestamp: string;
}

export interface NotifyItem {
  event: "pump" | "warning" | "grown" | "summary" | "health_issue" | string;
  time: string;
  message: string;
}

export interface NotifyQueryData {
  error: ApiErrorCode;
  notify_list: NotifyItem[];
}

export interface StatusCreateBody {
  user_id: string;
}

export interface StatusCreateData {
  error: ApiErrorCode;
}

export interface AnalysisCreateBody {
  user_id: string;
  type: "mom_baby" | "daily_summary" | "milk_analysis";
}

export interface AnalysisCreateData {
  error: ApiErrorCode;
  result?: boolean;
  message: string;
  analysis_card?: AgentAnalysisCard;
  /** 非渲染上下文：供后台提醒进入 AgentHub 后触发 LLM 接续解读。 */
  analysis_context?: AgentAnalysisCard;
}

export interface AgentAnalysisCardSection {
  id?: string;
  title: string;
  tone?: string;
  metrics?: Array<{
    label: string;
    value: string;
    detail?: string;
  }>;
  items?: string[];
  body?: string;
}

export interface AgentAnalysisCard {
  kind: "daily_summary" | "mom_baby" | string;
  title: string;
  subtitle?: string;
  status?: "normal" | "attention" | string;
  status_label?: string;
  status_tone?: "normal" | "attention" | "insufficient" | string;
  followup?: string;
  chips?: string[];
  reason?: string;
  sections?: AgentAnalysisCardSection[];
}

// ─── V1.2 兼容类型别名（相关端点已不在 V1.3 文档中）───────────────

export type PumpHealthUploadBody = Record<string, never>;
export type PumpHealthData = Record<string, never>;
export type FeedingAssessParams = Record<string, never>;
export type FeedingAssessData = Record<string, never>;
