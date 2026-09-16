import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { Link, Route, Routes, useLocation, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { Badge, Button, Card, EmptyState, Icon, Modal, SectionTitle, StatusDot } from '../components/UI'
import { useProduct } from '../store/ProductContext'
import { getConsultationDisplayState } from '../features/consultation/session'
import { isConsultationDemo } from '../features/consultation/appointments'
import { useRtcMedia } from '../features/consultation/rtcMedia'
import { rtcNetworkNotice } from '../features/consultation/rtcQuality'
import { buildWorkbenchClients } from '../features/consultation/workbenchClients'
import { babyAgeLabel } from '../features/baby/growthStandards'
import { formatPostpartumDay } from '../features/postpartum/stages'
import {
  appointmentIntakeReady,
  appointmentPatientDisplayName,
  formatAppointmentDayLabel,
  formatAppointmentTime,
  getWorkbenchAppointmentPresentation,
  isServerUnlinkedAppointment,
  partitionWorkbenchAppointments,
} from '../features/consultation/serverState'
import type { ConsultationAttendancePreviewDto } from '../api/consultation'
import type { AppointmentStatus, CarePlan, CareTask, ClinicalNote, ConsultationAttendanceOutcome, ProductState, RiskLevel } from '../types'
import momcozyLogo from '../assets/momcozy_logo.png'
import cozymateAvatar from '../assets/momcozy-agent.png'

const workNav = [
  { path: '/ibclc/appointments', label: '今日预约', icon: 'calendar' },
  { path: '/ibclc/daily-followup', label: '今日跟进', icon: 'plan' },
  { path: '/ibclc/availability', label: '我的日程', icon: 'clock' },
  { path: '/ibclc/cases', label: '我的客户', icon: 'note' },
  { path: '/ibclc/notifications', label: '工作提醒', icon: 'bell' }
]

function assignedProviderName(state: ProductState) {
  // The workbench header represents the authenticated professional, not a
  // display field carried by the selected appointment. Remote queue summaries
  // intentionally omit assigned-provider PII because the current actor is
  // already known from identity/assignment scope.
  return state.workbenchAssignment.ibclcId === 'ibclc-chen' ? 'Avery Chen, IBCLC' : 'Jamie Lee, IBCLC'
}

function CozymateSource() {
  return <span className="cozymate-source" role="img" aria-label="Cozymate 智能体"><img src={cozymateAvatar} alt="" /></span>
}

function providerShortName(state: ProductState) {
  return assignedProviderName(state).replace(/,?\s*IBCLC$/i, '')
}

function useWorkbenchState() {
  const { state } = useProduct()
  return state
}

type CaseTab = 'overview' | 'daily' | 'consultation' | 'note' | 'plan' | 'followup'
type CarePlanDraft = { title: string; goals: string; summary: string }
type CaseStageKey = 'consent' | 'intake' | 'risk' | 'consultation' | 'note' | 'plan' | 'followup' | 'complete' | 'empty'
type CaseTodo = string

interface CaseStage {
  key: CaseStageKey
  label: string
  tone: 'neutral' | 'rose' | 'green' | 'amber' | 'blue' | 'red'
  action: string
  detail: string
  cta: string
  target: CaseTab
}

interface CaseQueueItem {
  id: string
  name: string
  initials: string
  purchasedAt: string
  postpartumDay: number
  meta: string
  stateCode: string
  servicePackage: string
  consultationStage: string
  remainingSessions: number
  serviceDay: number
  serviceDaysTotal: number
  serviceStartedAt: string
  dailyStatus: string
  dailyStatusTone: CaseStage['tone']
  consultationsUsed: number
  consultationsTotal: number
  nextConsultation: string
  cycleEnd: string
  todo: CaseTodo
  status: string
  statusTone: CaseStage['tone']
  action: string
  actionHint: string
  risk: RiskLevel
  riskTone: 'green' | 'amber' | 'red'
  updated: string
  owner: string
}

interface ProviderServiceSummary {
  episodeId: string
  packageName: string
  purchasedAt: string
  startedAt: string
  endsAt: string
  serviceDay: number
  serviceDaysTotal: number
  consultationsUsed: number
  consultationsTotal: number
  statusLabel: string
  statusTone: CaseStage['tone']
  nextConsultation: string
}

const caseDemoPurchasedAt = (daysAgo: number) => new Date(Date.now() - daysAgo * 86_400_000).toISOString()
const CASES_PER_PAGE = 10
const TODAY_APPOINTMENTS_PER_PAGE = 10

interface ScheduleRow {
  id: string
  start: string
  end: string
  timezone: string
  title: string
  subtitle: string
  statusLabel: string
}

interface ConsultationPrepProfile {
  concern: string
  goal: string
  quote: string
  summary: string
  checks: string[]
}

interface AgentConversationExcerpt {
  role: '用户' | '智能体'
  time: string
  text: string
}

interface CaseIntelligenceProfile {
  personality: string[]
  emotion: {
    label: string
    detail: string
  }
  issues: string[]
  conversations: AgentConversationExcerpt[]
  recommendations: Array<{
    priority: '先确认' | '本次重点' | '后续观察'
    title: string
    advice: string
    rationale: string
  }>
}

const demoSecondaryCases: CaseQueueItem[] = [
  {
    id: 'olivia',
    name: 'Olivia Wang',
    initials: 'OW',
    purchasedAt: caseDemoPurchasedAt(1),
    postpartumDay: 8,
    meta: `${formatPostpartumDay(8)} · CA`,
    stateCode: 'CA',
    servicePackage: '舒适哺乳支持',
    consultationStage: '第 1 次 followup',
    remainingSessions: 1,
    serviceDay: 1,
    serviceDaysTotal: 7,
    serviceStartedAt: `${dateKey(new Date())}T00:00:00`,
    dailyStatus: '等待用户记录',
    dailyStatusTone: 'amber',
    consultationsUsed: 1,
    consultationsTotal: 2,
    nextConsultation: '今天 11:00',
    cycleEnd: addDays(new Date(), 6).toLocaleDateString('zh-CN'),
    todo: '提醒完成今日记录',
    status: '风险需复核',
    statusTone: 'red',
    action: '复核乳房红肿与发热记录',
    actionHint: '咨询前判断是否需要医疗转介。',
    risk: 'R1',
    riskTone: 'amber',
    updated: '12 分钟前',
    owner: 'Jamie Lee'
  },
  {
    id: 'sofia',
    name: 'Sofia Martinez',
    initials: 'SM',
    purchasedAt: caseDemoPurchasedAt(8),
    postpartumDay: 42,
    meta: `${formatPostpartumDay(42)} · CA`,
    stateCode: 'CA',
    servicePackage: '亲喂改善',
    consultationStage: '第 2 次 followup',
    remainingSessions: 0,
    serviceDay: 7,
    serviceDaysTotal: 7,
    serviceStartedAt: `${dateKey(addDays(new Date(), -6))}T00:00:00`,
    dailyStatus: '待完成周期总结',
    dailyStatusTone: 'blue',
    consultationsUsed: 2,
    consultationsTotal: 2,
    nextConsultation: '已完成',
    cycleEnd: new Date().toLocaleDateString('zh-CN'),
    todo: '发布服务总结',
    status: '待跟进',
    statusTone: 'green',
    action: '查看近 3 天喂养反馈',
    actionHint: '根据记录决定下次咨询是否调整计划。',
    risk: 'R0',
    riskTone: 'green',
    updated: '1 小时前',
    owner: 'Jamie Lee'
  },
  {
    id: 'emma',
    name: 'Emma Davis',
    initials: 'ED',
    purchasedAt: caseDemoPurchasedAt(4),
    postpartumDay: 16,
    meta: `${formatPostpartumDay(16)} · CA`,
    stateCode: 'CA',
    servicePackage: '奶量管理',
    consultationStage: '第 2 次 followup',
    remainingSessions: 1,
    serviceDay: 5,
    serviceDaysTotal: 7,
    serviceStartedAt: `${dateKey(addDays(new Date(), -4))}T00:00:00`,
    dailyStatus: '今日报告已生成',
    dailyStatusTone: 'green',
    consultationsUsed: 1,
    consultationsTotal: 2,
    nextConsultation: '今天 16:00',
    cycleEnd: addDays(new Date(), 2).toLocaleDateString('zh-CN'),
    todo: '查看报告并反馈',
    status: '方案待复核',
    statusTone: 'blue',
    action: '复核奶量管理计划',
    actionHint: '结合近 7 天泵奶记录确认调整方向。',
    risk: 'R0',
    riskTone: 'green',
    updated: '2 小时前',
    owner: 'Jamie Lee'
  }
]

const demoAppointmentPrepProfiles: Record<string, ConsultationPrepProfile> = {
  olivia: {
    concern: '乳房红肿、局部疼痛，近 24 小时有发热记录',
    goal: '缓解不适，确认是否需要医疗转介',
    quote: '“今天红肿比昨天更明显，喂养时会痛。”',
    summary: '存在需要优先核对的炎症相关信号。',
    checks: ['核对体温与症状持续时间', '确认是否出现寒战、红线或全身不适']
  },
  sofia: {
    concern: '亲喂节奏不稳定，宝宝在部分喂养中容易中断',
    goal: '根据近期记录调整喂养节奏',
    quote: '“有时候吃得很顺，有时候很快就停下来。”',
    summary: '近 3 天反馈显示亲喂表现有明显波动。',
    checks: ['对比不同时段的含乳与吞咽表现', '确认中断前是否出现困倦或不适']
  },
  emma: {
    concern: '泵奶量近期波动，对日常频次与节奏缺乏把握',
    goal: '确认可持续的奶量管理节奏',
    quote: '“我不确定是该增加次数，还是先观察几天。”',
    summary: '近 7 天记录可用于评估泵奶频次与产量变化。',
    checks: ['核对每日泵奶次数与大致产量', '了解休息、亲喂与泵奶之间的节奏']
  }
}

function primaryConsultationPrepProfile(state: ProductState): ConsultationPrepProfile {
  return {
    concern: state.intake.symptoms.join(' · ') || '待确认',
    goal: state.intake.feedingGoal || '待确认',
    quote: `“${state.intake.supportNeeded || '待确认'}”`,
    summary: '当前重点是含乳舒适度与夜间喂养节奏。',
    checks: ['视频中观察含乳姿势与吞咽节律', '确认疼痛出现的时点与持续时间']
  }
}

function primaryCaseIntelligenceProfile(state: ProductState): CaseIntelligenceProfile {
  const issues = state.intake.symptoms.length
    ? state.intake.symptoms
    : ['当前问题待在咨询中确认']

  return {
    personality: ['重视确定性', '偏好具体步骤', '愿意持续记录'],
    emotion: {
      label: '轻度焦虑',
      detail: '对含乳姿势与夜间频繁醒来缺乏把握，希望获得明确确认。'
    },
    issues,
    conversations: [
      { role: '用户', time: '今天 08:42', text: '最近夜里醒得很频繁，我总担心姿势不对。' },
      { role: '智能体', time: '今天 08:43', text: '可以先记录疼痛出现的时点，以及宝宝含乳后的吞咽节律。' },
      { role: '用户', time: '今天 08:45', text: '我更希望先确认姿势，再调整夜间安排。' }
    ],
    recommendations: [
      {
        priority: '先确认',
        title: '先核对含乳舒适度',
        advice: '在视频中观察含乳姿势、吞咽节律及疼痛出现的时点。',
        rationale: '客户的核心担忧是姿势是否正确；先确认基础动作，可减少后续调整的不确定性。'
      },
      {
        priority: '本次重点',
        title: '梳理夜间喂养节奏',
        advice: '结合近几晚醒来频率与有效喂养表现，一起确认当前节奏。',
        rationale: '夜醒频率不能单独判断喂养问题，需与吞咽、喂养后表现等信息一起核对。'
      },
      {
        priority: '后续观察',
        title: '给出一个可执行的小步骤',
        advice: '本次咨询只确认一项优先调整，并约定一个后续观察指标。',
        rationale: '客户偏好明确、具体的建议；同时调整过多会增加焦虑和执行负担。'
      }
    ]
  }
}

function riskTone(risk: RiskLevel): 'green' | 'amber' | 'red' {
  if (risk === 'R0') return 'green'
  if (risk === 'R1') return 'amber'
  return 'red'
}

function riskLabel(risk: RiskLevel) {
  return risk === 'R0' ? 'R0 · 无升级' : `${risk} · 需复核`
}

function getCaseStage(state: ProductState): CaseStage {
  if (!state.episode) {
    return { key: 'empty', label: '暂无分配客户', tone: 'neutral', action: '等待客户分配', detail: '客户分配后，病例会按下一动作排序。', cta: '查看客户', target: 'overview' }
  }
  if (state.intake.riskLevel !== 'R0') {
    return { key: 'risk', label: '风险需复核', tone: 'red', action: '先复核风险信号', detail: '在签署记录或发布方案前确认是否需要升级或转介。', cta: '查看风险', target: 'overview' }
  }
  if (state.consent.status !== 'active') {
    return { key: 'consent', label: 'Consent 待读', tone: 'amber', action: '确认数据授权范围', detail: '确认必要授权仍然有效，再继续查看病例内容。', cta: '查看授权', target: 'overview' }
  }
  if (!state.intake.submitted) {
    return { key: 'intake', label: 'Intake 待读', tone: 'amber', action: '查看 Intake 摘要', detail: '先确认用户的目标与当前困扰，再开始咨询记录。', cta: '查看 Intake', target: 'overview' }
  }
  if (state.appointment && (state.appointment.status === 'confirmed' || state.appointment.status === 'in_progress')) {
    const session = state.consultationSessions.find((item) => item.consultation.appointmentId === state.appointment?.id)
    const userArrived = session?.room.participants.user.presence === 'joined'
    return {
      key: 'consultation',
      label: state.appointment.status === 'in_progress' ? '咨询进行中' : userArrived ? '用户已进入' : '等待咨询',
      tone: state.appointment.status === 'in_progress' ? 'green' : 'blue',
      action: state.appointment.status === 'in_progress' ? '返回本次视频咨询' : userArrived ? '用户已就绪，进入咨询室' : '进入咨询室等待用户',
      detail: '只有 IBCLC 可以正式开始和结束咨询。',
      cta: state.appointment.status === 'in_progress' ? '返回咨询' : '进入咨询室',
      target: 'overview',
    }
  }
  if (!state.clinicalNote || state.clinicalNote.status === 'draft') {
    return { key: 'note', label: 'Clinical Note 待读', tone: 'rose', action: '记录本次 Clinical Note', detail: '完成主观描述、客观观察、专业评估和下一步。', cta: '开始记录', target: 'note' }
  }
  if (!state.carePlan || state.carePlan.status !== 'published') {
    return { key: 'plan', label: 'Care Plan 待读', tone: 'blue', action: '完成并发布 Care Plan', detail: '发布后会把行动任务同步到用户端日程中。', cta: '完善计划', target: 'plan' }
  }
  if (state.carePlan.tasks.some((task) => task.status !== 'completed')) {
    return { key: 'followup', label: '待跟进', tone: 'green', action: '查看执行反馈', detail: '关注任务完成情况和下一次复访节点。', cta: '查看跟进', target: 'followup' }
  }
  return { key: 'complete', label: '本周期已完成', tone: 'green', action: '查看周期结果', detail: '当前没有需要立即处理的病例动作。', cta: '查看结果', target: 'overview' }
}

function getCaseQueue(state: ProductState): CaseQueueItem[] {
  const demoCases = state.appointments.some((item) => item.id.startsWith('appt-demo-'))
    ? demoSecondaryCases.map((item) => ({ ...item, owner: providerShortName(state) }))
    : []
  if (!state.episode) return demoCases
  const stage = getCaseStage(state)
  const primaryAppointment = (state.appointment?.episodeId === state.episode.id ? state.appointment : undefined)
    ?? state.appointments.find((item) => item.episodeId === state.episode?.id)
  const episodeOrder = state.orders.find((item) => item.id === state.episode?.orderId) ?? state.order
  const servicePackage = episodeOrder ? state.packages.find((item) => item.id === episodeOrder.packageId) : undefined
  const packageName = servicePackage?.name
    ?? primaryAppointment?.serviceName
    ?? '喂养安心'
  const consultationsTotal = servicePackage?.sessions ?? 2
  const consultationStage = primaryAppointment?.consultationSequenceLabel
    ?? (primaryAppointment?.serviceType === 'follow_up' ? 'followup' : '首次咨询')
  const relatedAppointments = state.appointments.filter((item) => item.episodeId === state.episode?.id)
  const consultationsUsed = Math.min(consultationsTotal, relatedAppointments.filter((item) => item.status === 'completed' || item.status === 'in_progress').length)
  const nextAppointment = relatedAppointments
    .filter((item) => new Date(item.start).getTime() > Date.now() && item.status !== 'cancelled')
    .sort((a, b) => new Date(a.start).getTime() - new Date(b.start).getTime())[0]
  const elapsedDays = Math.floor((Date.now() - new Date(state.episode.startedAt).getTime()) / 86_400_000)
  const serviceDaysTotal = Math.max(1, Math.round((new Date(state.episode.endsAt).getTime() - new Date(state.episode.startedAt).getTime()) / 86_400_000))
  const serviceDay = Math.min(serviceDaysTotal, Math.max(1, elapsedDays + 1))
  const todo: CaseTodo = primaryAppointment?.status === 'in_progress'
    ? '返回咨询室'
    : primaryAppointment?.status === 'confirmed'
      ? '进入咨询室'
      : primaryAppointment?.status === 'completed' && (!state.clinicalNote || state.clinicalNote.status === 'draft')
        ? '填写 Clinical Note'
        : state.clinicalNote && state.clinicalNote.status !== 'draft' && (!state.carePlan || state.carePlan.status !== 'published')
          ? '发布 Care Plan'
          : serviceDay === serviceDaysTotal
            ? '发布服务总结'
            : '查看报告并反馈'
  return [{
    id: 'mia',
    name: state.user.name,
    initials: state.user.avatar,
    purchasedAt: episodeOrder?.createdAt ?? state.episode.startedAt,
    postpartumDay: state.user.postpartumDay,
    meta: `${formatPostpartumDay(state.user.postpartumDay)} · ${state.user.state}`,
    stateCode: state.user.state,
    servicePackage: packageName,
    consultationStage,
    remainingSessions: state.episode.remainingSessions,
    serviceDay,
    serviceDaysTotal,
    serviceStartedAt: state.episode.startedAt,
    dailyStatus: '今日报告已生成',
    dailyStatusTone: 'green',
    consultationsUsed,
    consultationsTotal,
    nextConsultation: nextAppointment
      ? `${new Date(nextAppointment.start).toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric' })} ${formatAppointmentTime(nextAppointment.start, nextAppointment.timezone)}`
      : consultationsUsed >= consultationsTotal ? '已完成' : `待安排第 ${consultationsUsed + 1} 次`,
    cycleEnd: new Date(state.episode.endsAt).toLocaleDateString('zh-CN'),
    todo,
    status: stage.label,
    statusTone: stage.tone,
    action: stage.action,
    actionHint: stage.detail,
    risk: state.intake.riskLevel,
    riskTone: riskTone(state.intake.riskLevel),
    updated: '刚刚',
    owner: providerShortName(state)
  }, ...demoCases]
}

function getProviderServicePackages(state: ProductState): ProviderServiceSummary[] {
  const currentProviderId = state.workbenchAssignment.ibclcId
  const now = Date.now()
  return state.episodes.flatMap((episode) => {
    const episodeAppointments = state.appointments.filter((appointment) => appointment.episodeId === episode.id)
    const hasExplicitAssignment = episodeAppointments.some((appointment) => Boolean(appointment.ibclcId))
    const belongsToCurrentProvider = episodeAppointments.some((appointment) => appointment.ibclcId === currentProviderId)
      || (!hasExplicitAssignment && episode.id === state.episode?.id && state.workbenchAssignment.status === 'assigned')
    if (!belongsToCurrentProvider) return []

    const order = state.orders.find((item) => item.id === episode.orderId)
    const servicePackage = order ? state.packages.find((item) => item.id === order.packageId) : undefined
    const startedAt = new Date(episode.startedAt).getTime()
    const endsAt = new Date(episode.endsAt).getTime()
    const serviceDaysTotal = Math.max(1, Math.round((endsAt - startedAt) / 86_400_000))
    const serviceDay = Math.min(serviceDaysTotal, Math.max(1, Math.floor((now - startedAt) / 86_400_000) + 1))
    const providerAppointments = episodeAppointments.filter((appointment) => !appointment.ibclcId || appointment.ibclcId === currentProviderId)
    const consultationsUsed = providerAppointments.filter((appointment) => appointment.status === 'completed' || appointment.status === 'in_progress').length
    const nextAppointment = providerAppointments
      .filter((appointment) => new Date(appointment.start).getTime() > now && appointment.status !== 'cancelled')
      .sort((a, b) => new Date(a.start).getTime() - new Date(b.start).getTime())[0]
    const status = episode.status === 'active'
      ? { label: '进行中', tone: 'green' as const }
      : episode.status === 'completed'
        ? { label: '已完成', tone: 'blue' as const }
        : episode.status === 'paused'
          ? { label: '已暂停', tone: 'amber' as const }
          : { label: episode.status === 'cancelled' ? '已取消' : '待开始', tone: 'neutral' as const }

    return [{
      episodeId: episode.id,
      packageName: servicePackage?.name ?? 'IBCLC 专家支持',
      purchasedAt: order?.createdAt ?? episode.startedAt,
      startedAt: episode.startedAt,
      endsAt: episode.endsAt,
      serviceDay,
      serviceDaysTotal,
      consultationsUsed,
      consultationsTotal: servicePackage?.sessions ?? 2,
      statusLabel: status.label,
      statusTone: status.tone,
      nextConsultation: nextAppointment
        ? `${new Date(nextAppointment.start).toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric' })} ${formatAppointmentTime(nextAppointment.start, nextAppointment.timezone)}`
        : consultationsUsed >= (servicePackage?.sessions ?? 2) ? '已完成' : `待安排第 ${consultationsUsed + 1} 次`,
    }]
  }).sort((a, b) => Date.parse(b.purchasedAt) - Date.parse(a.purchasedAt))
}

function getWorkbenchNotifications(state: ProductState) {
  // Care and safety notices address the customer. The professional workbench
  // only consumes operational appointment and case/service system events.
  return state.notifications.filter((item) => item.type === 'appointment' || item.type === 'system')
}

function dateKey(value: string | Date) {
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}/.test(value)) return value.slice(0, 10)
  const date = value instanceof Date ? value : new Date(value)
  const pad = (part: number) => String(part).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

function appointmentDateKey(value: string, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(new Date(value))
  const part = (type: Intl.DateTimeFormatPartTypes) => parts.find((item) => item.type === type)?.value ?? ''
  return `${part('year')}-${part('month')}-${part('day')}`
}

function formatDayLabel(value: string) {
  const date = new Date(value)
  const weekday = new Intl.DateTimeFormat('zh-CN', { weekday: 'short' }).format(date)
  return `${weekday} · ${date.getMonth() + 1} 月 ${date.getDate()} 日`
}

function parseLocalDate(value: string) {
  return new Date(`${value}T00:00:00`)
}

function startOfWeek(value: Date) {
  const date = new Date(value)
  date.setHours(0, 0, 0, 0)
  const day = date.getDay() || 7
  date.setDate(date.getDate() - day + 1)
  return date
}

function addDays(value: Date, amount: number) {
  const date = new Date(value)
  date.setDate(date.getDate() + amount)
  return date
}

function addMonths(value: Date, amount: number) {
  const date = new Date(value)
  const day = date.getDate()
  date.setDate(1)
  date.setMonth(date.getMonth() + amount)
  const lastDay = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate()
  date.setDate(Math.min(day, lastDay))
  return date
}

function formatCalendarDate(value: Date) {
  return `${value.getMonth() + 1} 月 ${value.getDate()} 日`
}

function formatCalendarRange(start: Date, end: Date) {
  const sameYear = start.getFullYear() === end.getFullYear()
  const startLabel = sameYear ? `${start.getMonth() + 1}月${start.getDate()}日` : `${start.getFullYear()}年${start.getMonth() + 1}月${start.getDate()}日`
  const endLabel = sameYear ? `${end.getMonth() + 1}月${end.getDate()}日` : `${end.getFullYear()}年${end.getMonth() + 1}月${end.getDate()}日`
  return `${startLabel} — ${endLabel}`
}

function formatCalendarWeekday(value: Date) {
  return new Intl.DateTimeFormat('zh-CN', { weekday: 'short' }).format(value)
}

function formatMonthHeading(value: Date) {
  return `${value.getFullYear()} 年 ${value.getMonth() + 1} 月`
}

function calendarMonthDays(value: Date) {
  const monthStart = new Date(value.getFullYear(), value.getMonth(), 1)
  const offset = (monthStart.getDay() || 7) - 1
  return Array.from({ length: 42 }, (_, index) => addDays(monthStart, index - offset))
}

function minutesSinceMidnight(value: string, timezone: string) {
  const [hour, minute] = formatAppointmentTime(value, timezone).split(':').map(Number)
  return hour * 60 + minute
}

function appointmentStatus(status: AppointmentStatus | undefined) {
  switch (status) {
    case 'confirmed': return { label: '已确认', tone: 'green' as const }
    case 'in_progress': return { label: '进行中', tone: 'rose' as const }
    case 'completed': return { label: '已完成', tone: 'blue' as const }
    case 'cancelled': return { label: '已取消', tone: 'neutral' as const }
    case 'no_show': return { label: '未到场', tone: 'amber' as const }
    case 'conflict': return { label: '有冲突', tone: 'red' as const }
    default: return { label: '等待确认', tone: 'amber' as const }
  }
}

function workbenchSection(pathname: string) {
  if (pathname.startsWith('/ibclc/daily-followup')) return '/ibclc/daily-followup'
  if (pathname.startsWith('/ibclc/cases') || pathname.startsWith('/ibclc/clients')) return '/ibclc/cases'
  if (pathname.startsWith('/ibclc/availability') || pathname.startsWith('/ibclc/schedule')) return '/ibclc/availability'
  if (pathname.startsWith('/ibclc/appointments') || pathname.startsWith('/ibclc/today') || pathname.startsWith('/ibclc/overview') || pathname.startsWith('/ibclc/dashboard')) return '/ibclc/appointments'
  if (pathname.startsWith('/ibclc/notifications')) return '/ibclc/notifications'
  if (pathname.startsWith('/ibclc/settings')) return '/ibclc/settings'
  return '/ibclc/appointments'
}

function goToCaseTab(navigate: ReturnType<typeof useNavigate>, tab: CaseTab, casePath = '/ibclc/cases/mia') {
  if (tab === 'note') navigate(`${casePath}/clinical-note`)
  else if (tab === 'plan') navigate(`${casePath}/care-plan`)
  else if (tab === 'daily' || tab === 'followup') navigate(`${casePath}/daily-followup`)
  else if (tab === 'consultation') navigate(`${casePath}/online-consultation`)
  else navigate(casePath)
}

export function WorkbenchAuthPage() {
  const navigate = useNavigate()
  const [step, setStep] = useState<'login' | 'mfa'>('login')
  const [email, setEmail] = useState('jamie.lee@careteam.example')
  const [code, setCode] = useState('')
  const [error, setError] = useState('')
  const submit = () => {
    setError('')
    if (step === 'login') {
      if (!email.includes('@')) { setError('请输入有效的工作邮箱'); return }
      setStep('mfa')
      return
    }
    if (code !== '246810') { setError('验证码不正确。演示验证码：246810'); return }
    navigate('/ibclc/appointments')
  }
  return <div className="auth-viewport work-auth"><div className="auth-card"><div className="auth-brand"><span className="brand-mark"><Icon name="spark" /></span><span>momcozy <em>IBCLC 工作台</em></span></div><p className="eyebrow">专业工作区</p><h1>进入病例环境</h1><label className="auth-label">工作邮箱<input aria-label="工作邮箱" value={email} onChange={(event) => setEmail(event.target.value)} type="email" /></label>{step === 'mfa' && <label className="auth-label">MFA 验证码<input aria-label="MFA 验证码" value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, '').slice(0, 6))} placeholder="246810" inputMode="numeric" /></label>}{error && <div className="inline-error" role="alert">{error}</div>}<Button size="lg" onClick={submit} disabled={step === 'mfa' && code.length !== 6}>{step === 'login' ? '继续' : '进入工作台'} <Icon name="arrow" /></Button><div className="auth-security"><Icon name="shield" /><span>MFA 已开启</span></div></div></div>
}

function WorkbenchShell({ children }: { children: ReactNode }) {
  const location = useLocation()
  const { state, consultation } = useProduct()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const queueCount = consultation.mode === 'server' ? buildWorkbenchClients(state.appointments).length
    : getCaseQueue(state).filter((item) => item.statusTone !== 'green' || item.status !== '本周期已完成').length
  const dailyFollowupCount = getCaseQueue(state).filter((item) => getDailyFollowupStatus(item).key === 'pending').length
  const unreadCount = getWorkbenchNotifications(state).filter((item) => !item.read).length
  const active = workbenchSection(location.pathname)
  const activeLabel = workNav.find((item) => active === item.path)?.label ?? (active === '/ibclc/settings' ? '执业与权限' : '今日预约')
  const breadcrumb = location.pathname.startsWith('/ibclc/daily-followup/')
    ? '今日跟进 / 客户跟进记录'
    : location.pathname.endsWith('/room')
    ? '今日预约 / 视频咨询'
    : location.pathname.includes('/appointments/') && (location.pathname.includes('/clinical-note') || location.pathname.includes('/care-plan'))
      ? '今日预约 / 咨询后记录'
    : location.pathname.includes('/cases/') || location.pathname.includes('/clients/')
      ? '我的客户 / 病例详情'
      : location.pathname.includes('/appointments/')
        ? '今日预约 / 咨询前资料'
        : activeLabel
  const providerName = assignedProviderName(state)
  const providerInitials = providerName.split(/[ ,]+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase()
  return <div className="workbench">
    {sidebarOpen && <button className="work-sidebar-backdrop" aria-label="关闭导航" onClick={() => setSidebarOpen(false)} />}
    <aside className={`work-sidebar ${sidebarOpen ? 'open' : ''}`}>
      <div className="work-brand"><div className="work-brand-logo-lockup"><span className="work-brand-logo-frame"><img className="work-brand-logo" src={momcozyLogo} alt="Momcozy" /></span><span className="work-brand-context">IBCLC 工作台</span></div></div>
      <nav className="work-nav" aria-label="工作台主导航">{workNav.map((item) => {
        const count = item.path === '/ibclc/cases' ? queueCount : item.path === '/ibclc/daily-followup' ? dailyFollowupCount : item.path === '/ibclc/notifications' ? unreadCount : 0
        return <Link key={item.path} to={item.path} className={active === item.path ? 'active' : ''} aria-current={active === item.path ? 'page' : undefined} onClick={() => setSidebarOpen(false)}><Icon name={item.icon} /><span>{item.label}</span>{count > 0 && <b className="nav-count">{count}</b>}</Link>
      })}</nav>
      <div className="workspace-context"><div className="provider-avatar">{providerInitials}</div><div><strong>{providerName}</strong><span>West Coast Care Team</span></div></div>
    </aside>
    <div className="work-main"><header className="work-topbar"><button className="mobile-menu" onClick={() => setSidebarOpen(!sidebarOpen)} aria-label={sidebarOpen ? '关闭导航' : '打开导航'}><Icon name="menu" /></button><div className="breadcrumb">IBCLC 工作台 <span>/</span> {breadcrumb}</div><div className="work-actions"><Link className="top-icon" aria-label={`工作提醒${unreadCount ? `，${unreadCount} 条未读` : ''}`} to="/ibclc/notifications"><Icon name="bell" />{unreadCount > 0 && <i aria-hidden="true" />}</Link></div></header><main className="work-content">{children}</main></div>
  </div>
}

function TodayAppointmentsPage() {
  const { state, dispatch, consultation } = useProduct()
  const navigate = useNavigate()
  const [now, setNow] = useState(() => Date.now())
  const [page, setPage] = useState(1)
  const { all: todayAppointments } = partitionWorkbenchAppointments(state.appointments, new Date(now))
  const totalPages = Math.max(1, Math.ceil(todayAppointments.length / TODAY_APPOINTMENTS_PER_PAGE))
  const currentPage = Math.min(page, totalPages)
  const pageStart = (currentPage - 1) * TODAY_APPOINTMENTS_PER_PAGE
  const visibleAppointments = todayAppointments.slice(pageStart, pageStart + TODAY_APPOINTMENTS_PER_PAGE)

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 30_000)
    return () => window.clearInterval(timer)
  }, [])

  useEffect(() => {
    setPage((current) => Math.min(current, totalPages))
  }, [totalPages])

  const openAppointment = (appointmentId: string, destination: 'room' | 'note') => {
    dispatch({ type: 'activateAppointment', appointmentId })
    if (destination === 'room') navigate(`/ibclc/appointments/${appointmentId}/room`)
    else navigate(`/ibclc/appointments/${appointmentId}/clinical-note`)
  }

  const renderAppointment = (appointment: ProductState['appointments'][number]) => {
    const unlinked = isServerUnlinkedAppointment(appointment)
    const patientName = appointmentPatientDisplayName(appointment, state)
    const patientState = appointment.patientState ?? (unlinked ? '州待确认' : state.user.state)
    const packageName = appointment.serviceName ?? '服务套餐待确认'
    const consultationSequence = appointment.consultationSequenceLabel
      ?? (appointment.serviceType === 'initial_consultation' ? '首次咨询' : 'followup')
    const intakeReady = appointmentIntakeReady(appointment, state)
    const startTime = new Date(appointment.start).getTime()
    const endTime = new Date(appointment.end).getTime()
    const temporalState = getWorkbenchAppointmentPresentation(appointment, new Date(now), isConsultationDemo(consultation.mode, import.meta.env.VITE_CONSULTATION_DEV_AUTH))
    const action = temporalState.action
    const duration = Math.max(0, Math.round((endTime - startTime) / 60_000))
    return <article className={`today-appointment-row ${temporalState.phase}`} key={appointment.id}>
      <div className="today-row-time"><span>{formatAppointmentDayLabel(appointment.start, appointment.timezone)}</span><strong>{formatAppointmentTime(appointment.start, appointment.timezone)}–{formatAppointmentTime(appointment.end, appointment.timezone)}</strong><span>{duration} 分钟</span></div>
      <div className="today-row-field today-row-client"><span className="today-mobile-label">客户</span><strong>{patientName}</strong></div>
      <div className="today-row-field today-row-location"><span className="today-mobile-label">所在州</span><strong>{patientState}</strong></div>
      <div className="today-row-field today-row-package"><span className="today-mobile-label">服务套餐</span><strong>{packageName}</strong></div>
      <div className="today-row-field today-row-stage"><span className="today-mobile-label">咨询阶段</span><strong>{consultationSequence}</strong></div>
      <div className="today-row-status"><div className="today-appointment-statuses"><Badge tone={temporalState.tone}>{temporalState.label}</Badge></div></div>
      <div className="today-row-action">{action ? <Button variant={action.destination === 'note' ? 'soft' : 'primary'} size="sm" title={unlinked && !intakeReady ? '咨询信息暂不可用' : undefined} disabled={unlinked && !intakeReady} onClick={() => openAppointment(appointment.id, action.destination)}>{action.label} <Icon name="arrow" /></Button> : <span className="today-row-action-empty">—</span>}</div>
    </article>
  }

  return <div className="work-page today-appointments-page">
    <div className="work-heading today-heading"><div className="work-heading-copy"><h1>今日预约</h1></div>{todayAppointments[0] && <Button size="sm" variant="soft" onClick={() => navigate(`/ibclc/appointments/${todayAppointments[0].id}/room?assistDemo=1`)}><Icon name="spark" /> 预览实时辅诊</Button>}</div>
    {(consultation.error || consultation.appointmentSyncError) && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{consultation.error || consultation.appointmentSyncError}</span></div>}
    {todayAppointments.length ? <>
      <section className="card today-appointment-list" aria-label="全部预约列表"><div className="today-appointment-list-head" aria-hidden="true"><span>时间</span><span>客户</span><span>所在州</span><span>服务套餐</span><span>咨询阶段</span><span>当前咨询状态</span><span>操作</span></div><div className="today-appointment-list-body">{visibleAppointments.map((appointment) => renderAppointment(appointment))}</div></section>
      <nav className="case-pagination today-pagination" aria-label="预约列表分页">
        <span aria-live="polite">显示 {pageStart + 1}–{pageStart + visibleAppointments.length} / {todayAppointments.length} 条预约 · 每页最多 {TODAY_APPOINTMENTS_PER_PAGE} 条 · 第 {currentPage} / {totalPages} 页</span>
        <div><Button size="sm" variant="ghost" disabled={currentPage === 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>上一页</Button><Button size="sm" variant="ghost" disabled={currentPage === totalPages} onClick={() => setPage((value) => Math.min(totalPages, value + 1))}>下一页</Button></div>
      </nav>
    </> : <Card className="today-empty-card"><div className="today-empty-icon"><Icon name="calendar" /></div><div className="today-empty-copy"><h2>暂无预约</h2><p>新预约确认后会自动同步，按预约日期显示。</p></div>{consultation.mode === 'server' && <Button size="sm" variant="soft" disabled={consultation.busy} onClick={() => { void consultation.refreshAppointments() }}>{consultation.busy ? '同步中…' : '刷新预约'}</Button>}</Card>}
  </div>
}

function LiveConsultationAssistDemo({ patientName }: { patientName: string }) {
  return <aside className="live-assist-panel focus" aria-label="智能体实时辅诊建议">
    <div className="live-assist-heading">
      <div className="live-assist-title"><span className="live-assist-mark"><Icon name="spark" /></span><span><strong>智能体实时辅诊</strong><small>视频内 Demo 展示</small></span></div>
      <span className="live-assist-live"><i />实时</span>
    </div>
    <div className="live-assist-question">
      <span>刚刚识别 · {patientName}</span>
      <strong>“含乳开始时很痛，过一会儿会缓解。”</strong>
    </div>
    <div className="live-assist-advice">
      <div><span>本次重点</span><small>建议 IBCLC</small></div>
      <p>建议在视频中观察含乳深度和喂后乳头形态，并追问疼痛持续时间与是否有破损。</p>
    </div>
    <div className="live-assist-prompts">
      <span>建议追问</span>
      <ul><li>疼痛通常持续多久？</li><li>喂后乳头是否变扁、发白或破损？</li></ul>
    </div>
    <div className="live-assist-footer">
      <span>仅供参考，请结合实时观察判断</span>
      <span className="live-assist-demo-label">Demo 数据</span>
    </div>
  </aside>
}

function WorkbenchConsultationRoomPage() {
  const { state, consultation } = useProduct()
  const { appointmentId = '' } = useParams()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const assistDemoMode = searchParams.get('assistDemo') === '1'
  const [endPending, setEndPending] = useState(false)
  const [attendancePending, setAttendancePending] = useState<ConsultationAttendanceOutcome>()
  const [attendancePreview, setAttendancePreview] = useState<ConsultationAttendancePreviewDto>()
  const [intakeLoadFailed, setIntakeLoadFailed] = useState(false)
  const joinedAppointmentRef = useRef<string | undefined>(undefined)
  const requestedIntakeRef = useRef<string | undefined>(undefined)
  const appointment = state.appointments.find((item) => item.id === appointmentId)
  const session = state.consultationSessions.find((item) => item.consultation.appointmentId === appointmentId)
  const displayState = session ? getConsultationDisplayState(session, 'ibclc') : 'not_joined'
  const rtc = useRtcMedia({
    credentials: session ? consultation.rtcCredentials[session.room.id] : undefined,
    onConnected: () => appointment ? consultation.mediaConnected(appointment.id, 'ibclc') : undefined,
    onReconnecting: () => appointment ? consultation.markReconnecting(appointment.id, 'ibclc') : undefined,
  })
  const networkNotice = rtcNetworkNotice(rtc.networkQuality)
  const userPresence = session?.room.participants.user.presence ?? 'not_joined'
  const userJoined = userPresence === 'joined'
  const active = assistDemoMode || displayState === 'active' || displayState === 'user_reconnecting' || displayState === 'user_left'
  const attendanceOutcome = session?.consultation.attendanceOutcome ?? appointment?.attendanceOutcome
  const userEverJoined = Boolean(session?.room.participants.user.joinedAt)
  const intakeReady = appointment ? appointmentIntakeReady(appointment, state) : false
  const patientName = appointment ? appointmentPatientDisplayName(appointment, state) : '预约用户'
  const patientInitials = patientName.split(/\s+/).map((part) => part[0]).join('').slice(0, 2).toUpperCase()
  const unlinked = appointment ? isServerUnlinkedAppointment(appointment) : false
  const providerInitials = assignedProviderName(state).split(/[ ,]+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase()
  const intake = consultation.mode === 'server'
    ? consultation.intakes[appointmentId]
    : intakeReady
      ? {
          symptoms: state.intake.symptoms,
          feedingGoal: state.intake.feedingGoal,
          supportNeeded: state.intake.supportNeeded,
          riskLevel: state.intake.riskLevel,
          profile: {
            stateCode: state.user.state,
            postpartumDay: state.user.postpartumDay,
            babyName: state.baby.name,
            babyAgeLabel: babyAgeLabel(state.baby.birthDate),
            feedingMode: state.baby.feedingMode,
          },
        }
      : undefined
  const demoCaseId = appointment?.episodeId.startsWith('episode-demo-') ? appointment.episodeId.replace('episode-demo-', '') : undefined
  const roomCase = demoSecondaryCases.find((item) => item.id === demoCaseId)
  const roomPrepBase = roomCase
    ? demoAppointmentPrepProfiles[roomCase.id]
    : primaryConsultationPrepProfile(state)
  const roomPrepProfile = roomCase || !intake
    ? roomPrepBase
    : {
        ...roomPrepBase,
        concern: intake.symptoms.join(' · ') || '待确认',
        goal: intake.feedingGoal || '待确认',
        quote: `“${intake.supportNeeded || '待确认'}”`,
      }
  const roomPostpartumLabel = roomCase
    ? formatPostpartumDay(roomCase.postpartumDay)
    : formatPostpartumDay(intake?.profile.postpartumDay ?? state.user.postpartumDay)
  const roomStateCode = appointment?.patientState ?? intake?.profile.stateCode ?? (unlinked ? '州待确认' : state.user.state)
  const roomServicePackage = appointment?.serviceName ?? roomCase?.servicePackage ?? '待确认'
  const roomConsultationStage = appointment?.consultationSequenceLabel
    ?? roomCase?.consultationStage
    ?? (appointment?.serviceType === 'follow_up' ? 'followup' : '首次咨询')

  useEffect(() => {
    if (!appointment || intakeReady) return
    requestedIntakeRef.current = undefined
    setIntakeLoadFailed(false)
  }, [appointment?.id, intakeReady])

  useEffect(() => {
    if (consultation.mode !== 'server' || !appointment || !intakeReady) return
    if (consultation.intakes[appointment.id] || requestedIntakeRef.current === appointment.id) return
    requestedIntakeRef.current = appointment.id
    setIntakeLoadFailed(false)
    void consultation.loadIntake(appointment.id).then((loaded) => setIntakeLoadFailed(!loaded))
  }, [appointment, consultation, intakeReady])

  useEffect(() => {
    if (!appointment || !intakeReady || (appointment.status !== 'confirmed' && appointment.status !== 'in_progress')) return
    if (joinedAppointmentRef.current === appointment.id) return
    joinedAppointmentRef.current = appointment.id
    void consultation.join(appointment.id, 'ibclc')
  }, [appointment?.id, appointment?.status, consultation, intakeReady])
  useEffect(() => {
    if (rtc.isLiveKit || !appointment || (appointment.status !== 'confirmed' && appointment.status !== 'in_progress')) return
    const reconnecting = () => { void consultation.markReconnecting(appointment.id, 'ibclc') }
    const reconnected = () => { void consultation.join(appointment.id, 'ibclc') }
    window.addEventListener('offline', reconnecting)
    window.addEventListener('online', reconnected)
    return () => {
      window.removeEventListener('offline', reconnecting)
      window.removeEventListener('online', reconnected)
    }
  }, [appointment?.id, appointment?.status, consultation, rtc.isLiveKit])

  if (!appointment) return <div className="work-page"><button className="back-button" onClick={() => navigate('/ibclc/appointments')}>返回今日预约</button><Card><EmptyState title="找不到这场咨询" body="该预约可能已取消或不在当前分配范围。" /></Card></div>
  const finish = async () => {
    const ended = await consultation.end(appointment.id, 'completed')
    if (!ended) return
    await rtc.disconnect()
    setEndPending(false)
    navigate(`/ibclc/appointments/${appointment.id}/clinical-note`)
  }
  const leave = async () => {
    await rtc.disconnect()
    const left = await consultation.leave(appointment.id, 'ibclc')
    if (!left) return
    navigate('/ibclc/appointments')
  }
  const openAttendance = async (outcome: ConsultationAttendanceOutcome) => {
    consultation.clearError()
    setAttendancePending(outcome)
    setAttendancePreview(undefined)
    const preview = await consultation.previewAttendance(appointment.id, outcome)
    if (preview) setAttendancePreview(preview)
  }
  const confirmAttendance = async () => {
    if (!attendancePending || !attendancePreview?.allowed) return
    const recorded = await consultation.recordAttendance(appointment.id, attendancePending)
    if (!recorded) return
    setAttendancePending(undefined)
    setAttendancePreview(undefined)
    navigate('/ibclc/appointments')
  }
  const closeAttendance = () => {
    if (consultation.busy) return
    setAttendancePending(undefined)
    setAttendancePreview(undefined)
    consultation.clearError()
  }
  const waitCopy = displayState === 'reconnecting'
    ? { title: '正在恢复工作台连接', detail: '网络恢复后会自动回到本次咨询。' }
    : displayState === 'ready_to_start'
    ? { title: `${patientName} 已进入咨询室`, detail: '双方已准备好，由你正式开始本次咨询。' }
    : displayState === 'user_reconnecting'
      ? { title: `${patientName} 正在重新连接`, detail: '咨询不会自动结束，可以继续等待。' }
      : displayState === 'user_left'
        ? { title: `${patientName} 暂时离开`, detail: '对方可以从妈妈主页重新进入。' }
        : { title: `等待 ${patientName} 进入`, detail: '你可以保持此页开启，用户进入后状态会自动更新。' }
  const attendanceTitle = attendancePending === 'user_no_show' ? '记录用户未到场？' : '记录技术故障？'
  const attendanceCopy = !attendancePreview
    ? '正在核对当前咨询状态…'
    : attendancePreview.allowed
      ? attendancePending === 'user_no_show'
        ? '确认后将关闭本次房间并记录用户未到场。本次不会扣减用户的咨询次数。'
        : '确认后将标记本次视频未能完成并关闭房间。本次不会扣减用户的咨询次数。'
      : attendancePreview.reason === 'too_early' && attendancePreview.eligible_at
        ? `仍在到场宽限期内，${formatAppointmentTime(attendancePreview.eligible_at, appointment.timezone)} 后才可记录未到场。`
        : attendancePreview.reason === 'participant_joined'
          ? '用户已经进入过咨询室，不能记录为未到场；如连接中断，请记录技术故障。'
          : attendancePreview.reason === 'terminal'
            ? '本次咨询已有最终结果，不能再次修改。'
            : '当前咨询状态不支持记录这项结果，请刷新后重试。'
  return <div className="work-page work-consultation-room-page">
    <button className="back-button" onClick={() => { if (assistDemoMode) navigate('/ibclc/appointments'); else void leave() }}>返回今日预约</button>
    <ClientProfileCard initials={roomCase?.initials ?? (unlinked ? patientInitials : state.user.avatar)} name={patientName} postpartumLabel={roomPostpartumLabel} stateCode={roomStateCode} servicePackage={roomServicePackage} consultationStage={roomConsultationStage} />
    {!assistDemoMode && consultation.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{consultation.error}</span></div>}
    {intakeReady && intake && <ConsultationPrepCards profile={roomPrepProfile} />}
    {intakeReady && !intake && <Card className="work-intake-load-state"><p>{intakeLoadFailed ? '暂时无法读取客户自述与智能体整理。' : '正在载入客户自述与智能体整理…'}</p>{intakeLoadFailed && <Button size="sm" variant="soft" onClick={() => {
        if (!appointment) return
        requestedIntakeRef.current = appointment.id
        setIntakeLoadFailed(false)
        consultation.clearError()
        void consultation.loadIntake(appointment.id).then((loaded) => setIntakeLoadFailed(!loaded))
      }}>重新载入</Button>}</Card>}
    {attendanceOutcome ? <Card className="work-room-blocked work-room-outcome"><Icon name={attendanceOutcome === 'user_no_show' ? 'clock' : 'wifi'} /><h2>{attendanceOutcome === 'user_no_show' ? '已记录用户未到场' : '已记录技术故障'}</h2><p>{attendanceOutcome === 'user_no_show' ? '本次预约已结束，未扣减用户的咨询次数。' : '本次视频未能完成，未扣减用户的咨询次数，也无需填写咨询记录。'}</p><Button variant="soft" onClick={() => navigate('/ibclc/appointments')}>返回预约列表</Button></Card> : !intakeReady ? <Card className="work-room-blocked"><Icon name="note" /><h2>咨询前信息暂不可用</h2><p>用户尚未提交，或已关闭本次服务授权。恢复可用后会自动更新。</p><Button variant="soft" onClick={() => navigate('/ibclc/appointments')}>返回预约列表</Button></Card> : !assistDemoMode && (appointment.status === 'completed' || displayState === 'ended') ? <Card className="work-room-blocked"><Icon name="check" /><h2>本次咨询已结束</h2><p>请完成 Clinical Note 和给用户的总结。</p><Button onClick={() => navigate(`/ibclc/appointments/${appointment.id}/clinical-note`)}>填写咨询记录</Button></Card> : <section className="work-video-room" aria-label={`与 ${patientName} 的视频咨询`}>
      <div className={`work-video-stage ${active ? 'active' : 'waiting'}`} data-rtc-status={rtc.isLiveKit ? rtc.status : 'mock'}><span className="video-demo-pill">{assistDemoMode ? '前端模拟 · 实时辅诊' : rtc.isLiveKit ? `LiveKit · ${rtc.status === 'connected' ? '媒体已连接' : rtc.status === 'reconnecting' ? '正在重连' : '正在连接'}` : consultation.mode === 'server' ? '服务端状态 · Mock 视频' : 'Demo · 双端实时联动'}</span><video ref={rtc.remoteVideoRef} className={`rtc-remote-video ${rtc.remoteVideoAvailable && active ? 'visible' : ''}`} autoPlay playsInline data-testid="ibclc-remote-video" /><audio ref={rtc.remoteAudioRef} autoPlay data-testid="ibclc-remote-audio" />{active && (userJoined || assistDemoMode) ? <>{!rtc.remoteVideoAvailable && <div className="work-video-remote-avatar">{unlinked ? patientInitials : state.user.avatar}</div>}<h2>{patientName}</h2><span className="video-connected"><StatusDot tone="green" /> {assistDemoMode ? '演示对话中' : (rtc.isLiveKit ? rtc.remoteParticipantConnected : true) ? '已连接' : '重新连接中'}</span></> : <div className="work-video-waiting"><span><Icon name="video" /></span><h2>{waitCopy.title}</h2><p>{rtc.isLiveKit && rtc.status === 'connecting' ? '正在建立安全的视频连接' : waitCopy.detail}</p></div>}<div className={`work-video-self ${rtc.cameraOn ? '' : 'off'}`}><video ref={rtc.localVideoRef} className={rtc.isLiveKit && rtc.cameraOn ? 'visible' : ''} autoPlay muted playsInline data-testid="ibclc-local-video" /><span>{rtc.cameraOn ? providerInitials : <Icon name="video" />}</span><small>你</small></div>{active && <LiveConsultationAssistDemo patientName={patientName} />}</div>
      {rtc.error && <div className="video-media-warning" role="alert"><Icon name="wifi" /><span>{rtc.error}</span></div>}
      {networkNotice && <div className={`video-network-notice ${networkNotice.tone}`} aria-live="polite"><Icon name="wifi" /><span><strong>{networkNotice.title}</strong><small>{networkNotice.detail}</small></span></div>}
      {rtc.audioPlaybackBlocked && <button type="button" className="video-enable-audio" onClick={() => { void rtc.enableAudioPlayback() }}>点击开启通话声音</button>}
      {displayState === 'ready_to_start' && <div className="work-room-start ready"><div className="meeting-readiness"><span className="meeting-readiness-icon"><Icon name="check" /></span><div><strong>双方已就绪</strong><span>现在可以启动会议</span></div></div><Button size="lg" disabled={consultation.busy} onClick={() => { void consultation.start(appointment.id) }}>{consultation.busy ? '正在启动…' : '启动会议'}</Button></div>}
      {displayState !== 'ready_to_start' && !active && <div className="work-room-start waiting"><div className="meeting-readiness"><span className="meeting-readiness-icon"><Icon name="clock" /></span><div><strong>等待用户进入</strong><span>用户到达后才可以启动会议</span></div></div><Button size="lg" disabled>启动会议</Button></div>}
      {active && <div className="work-video-controls"><button className={rtc.microphoneOn ? '' : 'off'} disabled={rtc.mediaBusy} onClick={() => { void rtc.toggleMicrophone() }}><Icon name="mic" /><span>{rtc.microphoneOn ? '麦克风' : '已静音'}</span></button><button className={rtc.cameraOn ? '' : 'off'} disabled={rtc.mediaBusy} onClick={() => { void rtc.toggleCamera() }}><Icon name="video" /><span>{rtc.cameraOn ? '摄像头' : '已关闭'}</span></button><button className="end" onClick={() => { if (assistDemoMode) navigate('/ibclc/appointments'); else setEndPending(true) }}><Icon name="stop" /><span>{assistDemoMode ? '结束演示' : '结束咨询'}</span></button></div>}
      {!active && !userEverJoined && <div className="work-room-exception-actions"><button type="button" disabled={consultation.busy} onClick={() => { void openAttendance('user_no_show') }}>记录用户未到场</button></div>}
    </section>}
    {endPending && <Modal title="结束本次咨询？" className="work-end-consultation-modal" onClose={() => setEndPending(false)}><div className="video-end-content"><p>结束后，妈妈端会离开视频并等待你发布咨询总结。</p><div className="video-end-actions"><Button size="lg" onClick={() => setEndPending(false)}>继续咨询</Button><Button size="lg" variant="danger" disabled={consultation.busy} onClick={() => { void finish() }}>{consultation.busy ? '正在结束…' : '确认结束'}</Button></div></div></Modal>}
    {attendancePending && <Modal title={attendanceTitle} className="work-attendance-modal" showClose={!consultation.busy} onClose={closeAttendance}><div className="work-attendance-content"><div className={`work-attendance-summary ${attendancePreview?.allowed ? 'eligible' : ''}`}><span><Icon name={attendancePending === 'user_no_show' ? 'clock' : 'wifi'} /></span><div><strong>{attendancePending === 'user_no_show' ? '用户未到场' : '技术故障'}</strong><p>{attendanceCopy}</p></div></div>{consultation.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{consultation.error}</span></div>}<div className="video-end-actions"><Button size="lg" variant="soft" disabled={consultation.busy} onClick={closeAttendance}>{attendancePreview?.allowed ? '返回检查' : '关闭'}</Button>{attendancePreview?.allowed && <Button size="lg" disabled={consultation.busy} onClick={() => { void confirmAttendance() }}>{consultation.busy ? '正在记录…' : '确认并结束'}</Button>}</div></div></Modal>}
  </div>
}

function getDailyFollowupStatus(item: CaseQueueItem) {
  return ['已跟进', 'IBCLC 已反馈'].includes(item.dailyStatus)
    ? { key: 'completed' as const, label: '已跟进', tone: 'neutral' as const }
    : { key: 'pending' as const, label: '待反馈', tone: 'red' as const }
}

function dailyFollowupDate(item: CaseQueueItem, day: number) {
  const date = new Date(item.serviceStartedAt)
  date.setDate(date.getDate() + day - 1)
  return date
}

function DailyFollowupsPage() {
  const state = useWorkbenchState()
  const [params, setParams] = useSearchParams()
  const query = params.get('q') ?? ''
  const filter = ['pending', 'completed'].includes(params.get('status') ?? '') ? params.get('status')! : 'all'
  const providerServices = getProviderServicePackages(state)
  const cases = getCaseQueue(state).map((item) => ({
    ...item,
    services: item.id === 'mia' && providerServices.length ? providerServices : [{
      episodeId: item.id,
      packageName: item.servicePackage,
      serviceDay: item.serviceDay,
      serviceDaysTotal: item.serviceDaysTotal,
    }],
  }))
  const filters = [
    { key: 'all', label: '全部' },
    { key: 'pending', label: '待反馈' },
    { key: 'completed', label: '已跟进' },
  ]
  const filtered = cases
    .filter((item) => (filter === 'all' || getDailyFollowupStatus(item).key === filter)
      && `${item.name} ${item.id} ${item.services.map((service) => service.packageName).join(' ')}`.toLowerCase().includes(query.trim().toLowerCase()))
    .sort((a, b) => Number(getDailyFollowupStatus(a).key === 'completed') - Number(getDailyFollowupStatus(b).key === 'completed'))
  const updateFilter = (key: string, value: string) => {
    const next = new URLSearchParams(params)
    if (value && value !== 'all') next.set(key, value)
    else next.delete(key)
    setParams(next, { replace: true })
  }
  const search = params.toString() ? `?${params.toString()}` : ''
  return <div className="work-page daily-followups-page">
    <div className="work-heading"><div className="work-heading-copy"><h1>今日跟进</h1><p className="work-heading-subtitle">查看 AI 每日用户状态报告，核对后给予专业反馈。</p></div></div>
    <div className="queue-toolbar daily-followups-toolbar">
      <div className="daily-followups-filters" role="group" aria-label="跟进状态筛选">{filters.map((option) => <button key={option.key} aria-pressed={filter === option.key} className={filter === option.key ? 'selected' : ''} onClick={() => updateFilter('status', option.key)}>{option.label}<span>{cases.filter((item) => option.key === 'all' || getDailyFollowupStatus(item).key === option.key).length}</span></button>)}</div>
      <label className="search-field"><Icon name="search" /><input aria-label="搜索跟进客户" placeholder="搜索客户姓名或服务套餐" value={query} onChange={(event) => updateFilter('q', event.target.value)} /></label>
    </div>
    <section className="card daily-followups-table" aria-label="今日跟进客户列表">
      <div className="daily-followups-table-head" aria-hidden="true"><span>客户名称</span><span>服务套餐</span><span>服务进度</span><span>跟进状态</span></div>
      {filtered.map((item) => {
        const status = getDailyFollowupStatus(item)
        return <Link className="daily-followups-row" key={item.id} to={`/ibclc/daily-followup/${item.id}${search}`} aria-label={`${item.name}，${status.label}，查看今日跟进`}>
          <strong className="daily-followups-name">{item.name}</strong>
          <div className="daily-followups-services">{item.services.map((service) => <div className="daily-followups-service-line" key={service.episodeId}><span className="daily-followups-package">{service.packageName}</span><span className="daily-followups-progress">第 {service.serviceDay}/{service.serviceDaysTotal} 天</span></div>)}</div>
          <div className={`daily-followups-status ${status.key}`}><Badge tone={status.tone}>{status.label}</Badge></div>
        </Link>
      })}
      {!filtered.length && <div className="daily-followups-empty" role="status"><span>{query.trim() ? '未找到匹配的客户' : filter === 'completed' ? '暂无已跟进客户' : filter === 'pending' ? '暂无待反馈客户' : '暂无今日跟进客户'}</span>{query && <button className="text-button" onClick={() => updateFilter('q', '')}>清除搜索</button>}</div>}
    </section>
  </div>
}

function ServerClientsPage() {
  const { state, consultation } = useProduct()
  const [query, setQuery] = useState('')
  const clients = buildWorkbenchClients(state.appointments)
  const filtered = clients.filter((item) => `${item.name} ${item.services.join(' ')}`.toLowerCase().includes(query.trim().toLowerCase()))
  return <div className="work-page cases-page clients-page">
    <div className="work-heading"><div className="work-heading-copy"><h1>客户管理</h1><p className="work-heading-subtitle">已确认预约的客户自动同步到这里，同一客户的多次预约合并展示。</p></div><Button size="sm" variant="soft" disabled={consultation.busy} onClick={() => { void consultation.refreshAppointments() }}>刷新客户</Button></div>
    {consultation.appointmentSyncError && <div className="inline-warning" role="alert">{consultation.appointmentSyncError}</div>}
    <div className="queue-toolbar"><label className="search-field"><Icon name="search" /><input aria-label="搜索客户姓名或服务" placeholder="搜索客户姓名或服务" value={query} onChange={(event) => setQuery(event.target.value)} /></label></div>
    <p className="queue-meta" aria-live="polite">{filtered.length} 位客户 · 仅展示当前 IBCLC 获授权的预约与服务</p>
    {filtered.length ? <div className="case-table" aria-label="客户列表"><div className="table-head"><span>用户</span><span>关联服务</span><span>咨询记录</span></div>{filtered.map((item) => <Link className="case-table-row" key={item.id} to={`/ibclc/clients/remote/${encodeURIComponent(item.id)}`} aria-label={`${item.name}，${item.services.join('、')}，查看客户`}>
      <div className="table-user"><div className="case-avatar">{item.name.slice(0, 1)}</div><div><strong>{item.name}</strong><span>{item.appointments.length} 条预约记录</span></div></div>
      <div className="case-current-service"><strong>真人 IBCLC 专家支持</strong><span>{item.services.join('、') || '服务信息待确认'}</span></div>
      <div className="case-service-progress"><strong>已完成 {item.appointments.filter((appointment) => appointment.status === 'completed').length} 次咨询</strong><small>查看预约时间、咨询状态与已授权资料 <Icon name="arrow" /></small></div>
    </Link>)}</div> : <Card><EmptyState title={query ? '未找到匹配的客户' : consultation.appointmentSyncError ? '客户列表暂时无法读取' : '暂无客户'} body={query ? '请尝试其他姓名或服务名称。' : '已确认分配给你的预约会自动建立客户记录。'} /></Card>}
  </div>
}

function ServerClientPage() {
  const { state, consultation } = useProduct()
  const { clientId } = useParams()
  const [intakeAppointmentId, setIntakeAppointmentId] = useState('')
  const client = buildWorkbenchClients(state.appointments).find((item) => item.id === clientId)
  const intakeAppointment = client?.appointments.find((item) => item.id === intakeAppointmentId)
  const intake = intakeAppointment?.intakeReady ? consultation.intakes[intakeAppointment.id] : undefined
  const openIntake = (appointment: ProductState['appointments'][number]) => {
    setIntakeAppointmentId(appointment.id)
    if (appointment.intakeReady) void consultation.loadIntake(appointment.id)
  }
  const navigate = useNavigate()
  return <div className="work-page case-page server-client-page"><button className="back-button" onClick={() => navigate('/ibclc/cases')}>返回客户管理</button>
    {client ? <><div className="work-heading"><div className="work-heading-copy"><h1>{client.name}</h1><p className="work-heading-subtitle">{client.services.join(' · ')} · 仅展示你负责的预约</p></div></div>
      <Card><SectionTitle title="咨询记录" /><div className="online-consultation-list">{client.appointments.map((appointment) => <div key={appointment.id}><div><strong>{appointment.serviceName}</strong><p>{formatAppointmentDayLabel(appointment.start, appointment.timezone)} · {formatAppointmentTime(appointment.start, appointment.timezone)}–{formatAppointmentTime(appointment.end, appointment.timezone)}（{appointment.timezone}）</p></div><Badge tone={appointment.status === 'completed' ? 'blue' : 'green'}>{appointment.status === 'completed' ? '已完成' : appointment.status === 'in_progress' ? '咨询中' : appointment.status === 'no_show' ? '未出席' : '已预约'}</Badge><Button size="sm" variant="soft" disabled={consultation.busy} onClick={() => openIntake(appointment)}>{appointment.intakeReady ? '查看咨询资料' : '查看资料状态'}</Button>{appointment.status === 'completed' && <Button size="sm" onClick={() => navigate(`/ibclc/appointments/${appointment.id}/clinical-note`)}>查看咨询记录</Button>}</div>)}</div></Card>
      {intakeAppointment && <Card><SectionTitle title="本次咨询资料" />{!intakeAppointment.intakeReady ? <p>客户尚未完成信息采集或未授权查看，本页不会展示其他客户或本地演示资料。</p> : consultation.busy ? <p role="status">正在读取已授权资料…</p> : consultation.error ? <div role="alert">{consultation.error}<Button size="sm" onClick={() => openIntake(intakeAppointment)}>重试</Button></div> : intake ? <div className="appointment-prep-intake-grid"><div><span>当前困扰</span><strong>{intake.symptoms.join('、') || '未填写'}</strong></div><div><span>希望改善</span><strong>{intake.feedingGoal || '未填写'}</strong></div><div><span>补充情况</span><strong>{intake.supportNeeded || '未填写'}</strong></div></div> : <p>资料暂不可用。</p>}</Card>}
    </> : <Card><EmptyState title={consultation.appointmentSyncError ? '暂时无法读取客户' : '未找到此客户'} body="客户可能已不在当前授权范围，请返回列表刷新。" /></Card>}
  </div>
}

function CasesPage() {
  const { consultation } = useProduct()
  return consultation.mode === 'server' ? <ServerClientsPage /> : <DemoCasesPage />
}

function DemoCasesPage() {
  const state = useWorkbenchState()
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const cases = getCaseQueue(state)
  const purchaseTime = (value: string) => {
    const parsed = Date.parse(value)
    return Number.isNaN(parsed) ? 0 : parsed
  }
  const filtered = [...cases]
    .sort((a, b) => purchaseTime(b.purchasedAt) - purchaseTime(a.purchasedAt) || a.name.localeCompare(b.name))
    .filter((item) => `${item.name} ${item.id} ${item.meta} ${item.servicePackage} ${item.serviceDay} ${item.consultationsUsed} ${item.nextConsultation} ${item.cycleEnd}`.toLowerCase().includes(query.trim().toLowerCase()))
  const totalPages = Math.max(1, Math.ceil(filtered.length / CASES_PER_PAGE))
  const currentPage = Math.min(page, totalPages)
  const pageStart = (currentPage - 1) * CASES_PER_PAGE
  const visibleCases = filtered.slice(pageStart, pageStart + CASES_PER_PAGE)
  const resetSearch = () => { setQuery(''); setPage(1) }
  const showCount = cases.length > 0 || Boolean(query)
  return <div className="work-page cases-page clients-page">
    <div className="work-heading"><div className="work-heading-copy"><h1>客户管理</h1><p className="work-heading-subtitle">查看客户当前服务与服务进展。</p></div></div>
    <div className="queue-toolbar"><label className="search-field"><Icon name="search" /><span className="sr-only">搜索客户</span><input aria-label="搜索客户姓名或病例 ID" value={query} onChange={(event) => { setQuery(event.target.value); setPage(1) }} placeholder="搜索客户姓名或病例 ID" /></label></div>
    {showCount && <p className="queue-meta" aria-live="polite">显示 {filtered.length ? pageStart + 1 : 0}–{pageStart + visibleCases.length} / {filtered.length} 位客户 · 按购买时间从新到旧{query ? ` · 搜索“${query}”` : ''}</p>}
    {visibleCases.length ? <>
      <div className="case-table" aria-label="客户列表">
      <div className="table-head"><span>用户</span><span>当前服务</span><span>服务进展</span></div>
      {visibleCases.map((item) => <Link key={item.id} to={`/ibclc/cases/${item.id}`} className="case-table-row" aria-label={`${item.name}，当前服务 ${item.servicePackage}，服务第 ${item.serviceDay} / ${item.serviceDaysTotal} 天，已使用 ${item.consultationsUsed} / ${item.consultationsTotal} 次咨询，查看详情`}>
        <div className="table-user"><div className="case-avatar">{item.initials}</div><div><strong>{item.name}</strong><span>{formatPostpartumDay(item.postpartumDay)}</span></div></div>
        <div className="case-current-service"><strong>真人 IBCLC 专家支持</strong><span>{item.servicePackage} · {item.consultationsTotal} 次在线咨询</span></div>
        <div className="case-service-progress"><div><strong>第 {item.serviceDay} / {item.serviceDaysTotal} 天</strong><span>已咨询 {item.consultationsUsed} / {item.consultationsTotal} 次</span></div><span className="case-service-progress-track"><i style={{ width: `${Math.round(item.serviceDay / item.serviceDaysTotal * 100)}%` }} /></span><small>{item.cycleEnd} 结束 · {item.nextConsultation}</small></div>
      </Link>)}
      </div>
      <nav className="case-pagination" aria-label="客户列表分页">
        <span aria-live="polite">每页最多 {CASES_PER_PAGE} 位 · 第 {currentPage} / {totalPages} 页</span>
        <div><Button size="sm" variant="ghost" disabled={currentPage === 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>上一页</Button><Button size="sm" variant="ghost" disabled={currentPage === totalPages} onClick={() => setPage((value) => Math.min(totalPages, value + 1))}>下一页</Button></div>
      </nav>
    </> : <Card className="queue-empty-card"><div className="queue-empty-state"><div className="queue-empty-icon"><Icon name={cases.length ? 'search' : 'users'} /></div><div className="queue-empty-copy"><h3>{cases.length ? '未找到匹配的客户' : '暂无客户'}</h3><p>{cases.length ? `没有与“${query}”匹配的客户。` : '系统分配客户后，病例与待处理事项会显示在这里。'}</p>{cases.length > 0 && <Button size="sm" variant="soft" onClick={resetSearch}>清除搜索</Button>}</div></div></Card>}
  </div>
}

function ClientProfileCard({ initials, name, postpartumLabel, stateCode, servicePackage, consultationStage, detailLabel = '咨询阶段' }: { initials: string; name: string; postpartumLabel: string; stateCode: string; servicePackage: string; consultationStage: string; detailLabel?: string }) {
  return <Card className="appointment-prep-profile client-profile-card">
    <div className="appointment-prep-person"><div className="case-avatar large">{initials}</div><div><strong>{name}</strong><span>{postpartumLabel}</span></div></div>
    <div className="appointment-prep-fact"><span>所在州</span><strong>{stateCode}</strong></div>
    <div className="appointment-prep-fact"><span>服务套餐</span><strong>{servicePackage}</strong></div>
    <div className="appointment-prep-fact"><span>{detailLabel}</span><strong>{consultationStage}</strong></div>
  </Card>
}

function ClientDetailProfile({ initials, name, postpartumLabel, stateCode, providerName, services, selectedServiceId, onSelectService }: { initials: string; name: string; postpartumLabel: string; stateCode: string; providerName: string; services: ProviderServiceSummary[]; selectedServiceId?: string; onSelectService?: (episodeId: string) => void }) {
  return <Card className="client-detail-profile">
    <div className="client-detail-basics">
      <div className="appointment-prep-person"><div className="case-avatar large">{initials}</div><div><strong>{name}</strong><span>{postpartumLabel}</span></div></div>
      <div className="client-basic-fact"><span>所在州</span><strong>{stateCode}</strong></div>
      <div className="client-basic-fact"><span>当前服务关系</span><strong>{services.length} 个服务包</strong></div>
    </div>
    <div className="client-owned-services">
      <div className="client-owned-services-heading"><div><span>当前 IBCLC 负责的服务</span><strong>{providerName}</strong></div><small>仅展示由该 IBCLC 提供的服务包</small></div>
      {services.length ? <div className="client-service-options">{services.map((service) => {
        const selected = service.episodeId === selectedServiceId
        return <button type="button" className={selected ? 'selected' : ''} aria-pressed={selected} key={service.episodeId} onClick={() => onSelectService?.(service.episodeId)}>
          <span className="client-service-option-copy"><strong>{service.packageName}</strong><small>{new Date(service.purchasedAt).toLocaleDateString('zh-CN')} 购买 · 第 {service.serviceDay} / {service.serviceDaysTotal} 天</small></span>
          <Badge tone={service.statusTone}>{service.statusLabel}</Badge>
        </button>
      })}</div> : <p className="client-service-empty">当前没有由 {providerName} 负责的服务包。</p>}
    </div>
  </Card>
}

function ConsultationPrepCards({ profile, includeAiSummary = true }: { profile: ConsultationPrepProfile; includeAiSummary?: boolean }) {
  return <div className={`appointment-prep-grid${includeAiSummary ? '' : ' intake-only'}`}>
    <Card className="appointment-prep-intake"><SectionTitle title="客户自述" /><div className="appointment-prep-intake-grid"><div><span>当前困扰</span><strong>{profile.concern}</strong></div><div><span>希望改善</span><strong>{profile.goal}</strong></div></div><blockquote><span>客户原话</span><p>{profile.quote}</p></blockquote></Card>
    {includeAiSummary && <Card className="appointment-prep-ai"><SectionTitle title="智能体整理" action={<CozymateSource />} /><p className="appointment-prep-ai-summary">{profile.summary}</p><ul>{profile.checks.map((check) => <li key={check}><Icon name="check" /><span>{check}</span></li>)}</ul><small>AI 内容仅作为咨询准备，需由 IBCLC 在咨询中核对。</small></Card>}
  </div>
}

function CaseIntelligenceModules({ state }: { state: ProductState }) {
  const profile = primaryCaseIntelligenceProfile(state)
  const prep = primaryConsultationPrepProfile(state)

  return <div className="case-intelligence-grid">
    <Card className="agent-preconsult-card">
      <SectionTitle title="智能体预问诊" action={<CozymateSource />} />
      <div className="preconsult-summary-grid">
        <div className="preconsult-summary-item">
          <span>性格特征</span>
          <div className="preconsult-tags">{profile.personality.map((trait) => <span key={trait}>{trait}</span>)}</div>
        </div>
        <div className="preconsult-summary-item emotion">
          <span>当前情绪</span>
          <strong>{profile.emotion.label}</strong>
          <p>{profile.emotion.detail}</p>
        </div>
        <div className="preconsult-summary-item issues">
          <span>主要问题</span>
          <ul>{profile.issues.map((issue) => <li key={issue}>{issue}</li>)}</ul>
        </div>
      </div>
      <div className="conversation-history">
        <div className="conversation-history-title"><div><Icon name="chat" /><strong>历史对话</strong></div><span>最近 {profile.conversations.length} 条</span></div>
        <div className="conversation-list">{profile.conversations.map((conversation, index) => <div className={`conversation-row ${conversation.role === '用户' ? 'user' : 'agent'}`} key={`${conversation.role}-${index}`}>
          <span className="conversation-role">{conversation.role}</span>
          <p>{conversation.text}</p>
          <time>{conversation.time}</time>
        </div>)}</div>
      </div>
    </Card>
    <Card className="assist-recommendation-card">
      <SectionTitle title="辅诊建议" action={<CozymateSource />} />
      <div className="assist-context" aria-label="智能体整理的建议依据">
        <span>智能体整理 · 当前重点</span>
        <strong>{prep.summary}</strong>
        <ul>{prep.checks.map((check) => <li key={check}><Icon name="check" /><span>{check}</span></li>)}</ul>
      </div>
      <div className="assist-recommendation-list">{profile.recommendations.map((recommendation, index) => <article key={recommendation.title}>
        <span className="recommendation-index">{String(index + 1).padStart(2, '0')}</span>
        <div className="recommendation-content">
          <div className="recommendation-heading"><strong>{recommendation.title}</strong><Badge tone={index === 0 ? 'rose' : index === 1 ? 'green' : 'neutral'}>{recommendation.priority}</Badge></div>
          <p className="recommendation-advice">{recommendation.advice}</p>
          <div className="recommendation-rationale"><span>思考逻辑</span><p>{recommendation.rationale}</p></div>
        </div>
      </article>)}</div>
      <small className="assist-recommendation-note">AI 建议仅用于辅助决策，需由 IBCLC 结合咨询中的真实观察进行核对。</small>
    </Card>
  </div>
}

function ServiceCycleOverview({ item, onOpenDaily, onOpenConsultation }: { item: CaseQueueItem; onOpenDaily: () => void; onOpenConsultation: () => void }) {
  const todoOpensConsultation = /Consultation|Clinical|Care Plan|咨询/.test(item.todo)
  return <Card className="service-cycle-card">
    <SectionTitle title={`${item.serviceDaysTotal} 天服务周期`} action={<Badge tone="green">进行中 · Day {item.serviceDay}</Badge>} />
    <div className="service-cycle-progress" aria-label={`服务周期第 ${item.serviceDay} 天，共 ${item.serviceDaysTotal} 天`}><span><i style={{ width: `${Math.round(item.serviceDay / item.serviceDaysTotal * 100)}%` }} /></span><p>已进行 {item.serviceDay} 天</p><p>{item.cycleEnd} 结束</p></div>
    <div className="service-cycle-facts">
      <div><span>今日状态</span><strong>{item.dailyStatus}</strong><button className="text-button" onClick={onOpenDaily}>查看今日对话 <Icon name="arrow" /></button></div>
      <div><span>在线咨询</span><strong>{item.consultationsUsed} / {item.consultationsTotal} 次</strong><p>{item.nextConsultation}</p></div>
      <div><span>今日跟进</span><strong>AI 汇总今日对话</strong><p>IBCLC 确认回答或提交反馈</p></div>
      <div className="service-cycle-todo"><span>今日待办</span><strong>{item.todo}</strong><Button size="sm" variant="soft" onClick={todoOpensConsultation ? onOpenConsultation : onOpenDaily}>去处理</Button></div>
    </div>
  </Card>
}

const dailyReportSummaries = [
  '已完成服务目标确认，建立含乳舒适度基线。',
  '夜间醒来较频繁，喂养后的舒适度较前一日稳定。',
  '用户仍关注含乳姿势，愿意持续记录疼痛时点和吞咽节律。',
  '持续观察舒适度与夜间喂养节奏。',
  '将对比前四天记录，确认是否需要调整 Care Plan。',
  '准备第二次在线咨询所需的变化摘要。',
  '汇总本周变化、已确认动作和后续观察项。'
]

const dailyConversationReviews: Record<string, Array<{ question: string; answer: string }>> = {
  mia: [
    { question: '最近夜里醒得很频繁，是不是我的含乳姿势不对？', answer: '先记录疼痛出现的时点和宝宝含乳后的吞咽节律；咨询时再一起核对姿势。' },
    { question: '我想先确认姿势，再调整夜间安排，可以吗？', answer: '可以。先确认含乳舒适度，再结合近几晚记录逐步调整夜间喂养节奏。' },
  ],
  olivia: [
    { question: '今天红肿比昨天明显，喂养时也会痛，需要担心吗？', answer: '请记录体温、红肿范围和疼痛持续时间；如出现寒战、红线或全身不适，应及时联系医疗服务。' },
  ],
  sofia: [
    { question: '宝宝有时吃得很顺，有时很快停下来，应该怎么判断？', answer: '可以对比不同时段的吞咽表现、清醒程度和喂养后的状态，再判断是否需要调整节奏。' },
  ],
  emma: [
    { question: '奶量有波动，我应该增加泵奶次数还是先观察？', answer: '先连续记录泵奶频次、产量和休息情况，再根据趋势决定是否调整，避免一次改变太多因素。' },
  ],
}

function DailyFollowupPanel({ item }: { item: CaseQueueItem }) {
  const waitingForRecord = item.dailyStatus === '等待用户记录'
  const [reviewStatus, setReviewStatus] = useState<'idle' | 'confirmed' | 'feedback'>('idle')
  const [feedbackOpen, setFeedbackOpen] = useState(false)
  const [feedback, setFeedback] = useState('')
  const [feedbackError, setFeedbackError] = useState('')
  const conversations = dailyConversationReviews[item.id] ?? dailyConversationReviews.mia
  const confirmReview = () => {
    setReviewStatus('confirmed')
    setFeedbackOpen(false)
    setFeedbackError('')
  }
  const submitFeedback = () => {
    if (!feedback.trim()) {
      setFeedbackError('请填写具体意见后再提交。')
      return
    }
    setReviewStatus('feedback')
    setFeedbackOpen(false)
    setFeedbackError('')
  }
  return <Card className="daily-followup-card">
    <SectionTitle title="今日跟进" action={<span className="section-count">Day 1–Day {item.serviceDaysTotal}</span>} />
    <p className="daily-followup-intro">AI 汇总用户当天的问题与回答，IBCLC 负责确认或反馈修改意见。</p>
    <div className="daily-followup-list">{Array.from({ length: item.serviceDaysTotal }, (_, index) => {
      const day = index + 1
      const past = day < item.serviceDay
      const today = day === item.serviceDay
      const date = dailyFollowupDate(item, day)
      return <article className={today ? 'today' : past ? 'complete' : 'future'} key={day}>
        <div className="daily-followup-day"><span>Day</span><strong>{day}</strong></div>
        <div className="daily-followup-copy"><div className="daily-followup-heading"><div className="daily-followup-title"><time dateTime={dateKey(date)}>{date.toLocaleDateString('zh-CN')}</time><strong>{today ? '今日对话复核' : past ? '已完成跟进' : '待开始'}</strong></div>{(today || past) && <Badge tone={today ? reviewStatus === 'confirmed' ? 'green' : reviewStatus === 'feedback' ? 'amber' : 'neutral' : 'blue'}>{today ? waitingForRecord ? '等待用户对话' : reviewStatus === 'confirmed' ? '已确认' : reviewStatus === 'feedback' ? '已反馈' : '待复核' : 'IBCLC 已反馈'}</Badge>}</div>
          {past && <p>{dailyReportSummaries[Math.min(index, dailyReportSummaries.length - 1)]}</p>}
          {today && waitingForRecord && <p>用户今天与智能体产生对话后，将在这里显示问题与回答摘要。</p>}
          {today && !waitingForRecord && <div className="daily-dialogue-review">
            <div className="daily-dialogue-list">{conversations.map((conversation, conversationIndex) => <div className="daily-dialogue-item" key={`${conversation.question}-${conversationIndex}`}>
              <div><span>用户问题 {String(conversationIndex + 1).padStart(2, '0')}</span><p>{conversation.question}</p></div>
              <div><span>智能体回答</span><p>{conversation.answer}</p></div>
            </div>)}</div>
            {reviewStatus === 'confirmed' && <div className="daily-review-result confirmed" role="status"><Icon name="check" /><span>已确认：认可智能体今天的回答。</span></div>}
            {reviewStatus === 'feedback' && <div className="daily-review-result feedback" role="status"><Icon name="note" /><span>已反馈：不认可智能体回答，意见为“{feedback.trim()}”</span></div>}
            {feedbackOpen && <div className="daily-feedback-form"><label htmlFor={`daily-feedback-${item.id}`}>具体意见</label><textarea id={`daily-feedback-${item.id}`} value={feedback} onChange={(event) => { setFeedback(event.target.value); setFeedbackError('') }} rows={3} placeholder="请指出哪条回答不准确，以及建议如何修改。" />{feedbackError && <span role="alert">{feedbackError}</span>}<div><Button size="sm" variant="ghost" onClick={() => { setFeedbackOpen(false); setFeedbackError('') }}>取消</Button><Button size="sm" variant="secondary" onClick={submitFeedback}>提交反馈</Button></div></div>}
            {!feedbackOpen && <div className="daily-review-actions"><span>确认表示认可回答；反馈表示不认可并提供具体意见。</span><div><Button size="sm" variant={reviewStatus === 'confirmed' ? 'soft' : 'ghost'} onClick={confirmReview}>确认回答</Button><Button size="sm" variant={reviewStatus === 'feedback' ? 'soft' : 'secondary'} onClick={() => setFeedbackOpen(true)}>反馈修改</Button></div></div>}
          </div>}
        </div>
      </article>
    })}</div>
  </Card>
}

function OnlineConsultationPanel({ item, appointment, onOpenNote, onOpenRoom, onOpenSchedule }: { item: CaseQueueItem; appointment?: ProductState['appointments'][number]; onOpenNote: () => void; onOpenRoom: () => void; onOpenSchedule: () => void }) {
  const linkedAppointmentIndex = appointment
    ? appointment.status === 'completed' ? Math.max(0, item.consultationsUsed - 1) : Math.min(item.consultationsTotal - 1, item.consultationsUsed)
    : -1
  return <>
    <Card className="online-consultation-card">
      <SectionTitle title={`${item.consultationsTotal} 次 IBCLC 在线咨询`} action={<span className="section-count">已使用 {item.consultationsUsed} / {item.consultationsTotal} 次</span>} />
      <div className="online-consultation-list">{Array.from({ length: item.consultationsTotal }, (_, index) => {
        const sessionNumber = index + 1
        const completed = index < item.consultationsUsed
        const linkedAppointment = index === linkedAppointmentIndex ? appointment : undefined
        const statusLabel = completed ? '已完成' : linkedAppointment?.status === 'in_progress' ? '进行中' : linkedAppointment ? '已预约' : '待安排'
        const scheduleLabel = linkedAppointment
          ? `${formatAppointmentDayLabel(linkedAppointment.start, linkedAppointment.timezone)} · ${formatAppointmentTime(linkedAppointment.start, linkedAppointment.timezone)}`
          : completed ? '本服务包内已完成' : index === item.consultationsUsed ? item.nextConsultation : '待前序咨询完成后安排'
        return <div key={sessionNumber}><span className="consultation-number">{String(sessionNumber).padStart(2, '0')}</span><div><strong>第 {sessionNumber} 次在线咨询</strong><p>{scheduleLabel}</p></div><Badge tone={completed ? 'blue' : statusLabel === '进行中' ? 'green' : 'neutral'}>{statusLabel}</Badge>{linkedAppointment?.status === 'completed' ? <Button size="sm" variant="soft" onClick={onOpenNote}>填写 Clinical Note</Button> : linkedAppointment ? <Button size="sm" onClick={onOpenRoom}>{linkedAppointment.status === 'in_progress' ? '返回咨询室' : '进入咨询室'}</Button> : !completed && <Button size="sm" variant="soft" onClick={onOpenSchedule}>查看日程</Button>}</div>
      })}</div>
    </Card>
  </>
}

function DemoCaseOverview({ item, appointment, fromAppointments, onBack }: { item: CaseQueueItem; appointment?: ProductState['appointments'][number]; fromAppointments: boolean; onBack: () => void }) {
  const location = useLocation()
  const [tab, setTab] = useState<'overview' | 'daily' | 'consultation' | 'plan'>(() => location.pathname.includes('daily-followup') ? 'daily' : 'overview')
  const navigate = useNavigate()
  const profile = demoAppointmentPrepProfiles[item.id]
  const service: ProviderServiceSummary = { episodeId: `episode-demo-${item.id}`, packageName: item.servicePackage, purchasedAt: item.purchasedAt, startedAt: item.serviceStartedAt, endsAt: item.cycleEnd, serviceDay: item.serviceDay, serviceDaysTotal: item.serviceDaysTotal, consultationsUsed: item.consultationsUsed, consultationsTotal: item.consultationsTotal, statusLabel: item.serviceDay >= item.serviceDaysTotal ? '已完成' : '进行中', statusTone: item.serviceDay >= item.serviceDaysTotal ? 'blue' : 'green', nextConsultation: item.nextConsultation }
  return <div className="work-page case-page demo-case-page">
    <button className="back-button" onClick={onBack}>{location.pathname.startsWith('/ibclc/daily-followup/') || location.state?.fromDailyFollowup ? '返回今日跟进' : fromAppointments ? '返回今日预约' : '返回客户管理'}</button>
    <ClientDetailProfile initials={item.initials} name={item.name} postpartumLabel={formatPostpartumDay(item.postpartumDay)} stateCode={item.stateCode} providerName={item.owner} services={[service]} selectedServiceId={service.episodeId} />
    <div className="case-tabs" role="tablist" aria-label="客户服务工作区"><button role="tab" aria-selected={tab === 'overview'} className={tab === 'overview' ? 'active' : ''} onClick={() => setTab('overview')}>概览</button><button role="tab" aria-selected={tab === 'daily'} className={tab === 'daily' ? 'active' : ''} onClick={() => setTab('daily')}>今日跟进</button><button role="tab" aria-selected={tab === 'consultation'} className={tab === 'consultation' ? 'active' : ''} onClick={() => setTab('consultation')}>在线咨询</button><button role="tab" aria-selected={tab === 'plan'} className={tab === 'plan' ? 'active' : ''} onClick={() => setTab('plan')}>Care Plan</button></div>
    {tab === 'overview' && <ServiceCycleOverview item={item} onOpenDaily={() => setTab('daily')} onOpenConsultation={() => setTab('consultation')} />}
    {tab === 'daily' && <DailyFollowupPanel item={item} />}
    {tab === 'consultation' && <><OnlineConsultationPanel item={item} appointment={appointment} onOpenNote={() => appointment ? navigate(`/ibclc/appointments/${appointment.id}/clinical-note`) : navigate('/ibclc/appointments')} onOpenRoom={() => appointment && navigate(`/ibclc/appointments/${appointment.id}/room`)} onOpenSchedule={() => navigate('/ibclc/availability')} />{profile && <ConsultationPrepCards profile={profile} />}</>}
    {tab === 'plan' && <Card><EmptyState title="Care Plan 待完善" body="完成在线咨询并签署 Clinical Note 后，可在这里发布本周行动计划。" /></Card>}
  </div>
}

function AppointmentPrepOverview({ state, appointment, item, onBack }: { state: ProductState; appointment: ProductState['appointments'][number]; item?: CaseQueueItem; onBack: () => void }) {
  const isPrimaryCase = appointment.episodeId === state.episode?.id || appointment.patientDisplayName === state.user.name
  const patientName = appointmentPatientDisplayName(appointment, state)
  const patientState = appointment.patientState ?? state.user.state
  const initials = item?.initials ?? state.user.avatar
  const postpartumLabel = isPrimaryCase ? formatPostpartumDay(state.user.postpartumDay) : item ? formatPostpartumDay(item.postpartumDay) : '产后阶段待确认'
  const profile = isPrimaryCase
    ? primaryConsultationPrepProfile(state)
    : demoAppointmentPrepProfiles[item?.id ?? ''] ?? {
        concern: item?.action ?? '待确认',
        goal: item?.actionHint ?? '待确认',
        quote: '“待在咨询中进一步确认。”',
        summary: item?.actionHint ?? '暂无可用的智能体摘要。',
        checks: ['核对用户最近记录', '咨询中确认当前目标']
      }
  return <div className="work-page appointment-prep-page">
    <button className="back-button" onClick={onBack}>返回今日预约</button>
    <ClientProfileCard initials={initials} name={patientName} postpartumLabel={postpartumLabel} stateCode={patientState} servicePackage={appointment.serviceName ?? '待确认'} consultationStage={appointment.consultationSequenceLabel ?? '待确认'} />
    <ConsultationPrepCards profile={profile} />
  </div>
}

function CasePage() {
  const { dispatch } = useProduct()
  const state = useWorkbenchState()
  const providerServices = useMemo(() => getProviderServicePackages(state), [state])
  const [selectedServiceId, setSelectedServiceId] = useState(() => state.episode?.id ?? '')
  const location = useLocation()
  const { caseId = 'mia' } = useParams()
  const fromAppointments = location.pathname.startsWith('/ibclc/appointments/')
  const fromDailyFollowup = location.pathname.startsWith('/ibclc/daily-followup/')
  const returnPath = fromDailyFollowup ? `/ibclc/daily-followup${location.search}` : location.state?.fromDailyFollowup ? `/ibclc/daily-followup${location.state.followupSearch ?? ''}` : fromAppointments ? '/ibclc/appointments' : '/ibclc/cases'
  const returnLabel = fromDailyFollowup || location.state?.fromDailyFollowup ? '返回今日跟进' : fromAppointments ? '返回今日预约' : '返回客户管理'
  const routeTab: CaseTab = location.pathname.includes('care-plan')
    ? 'plan'
    : location.pathname.endsWith('/daily-followup') || location.pathname.includes('follow-ups') || (fromDailyFollowup && location.pathname.endsWith(`/${caseId}`))
      ? 'daily'
      : location.pathname.includes('online-consultation') || location.pathname.includes('clinical-note')
        ? 'consultation'
        : 'overview'
  const showClinicalNote = location.pathname.includes('clinical-note')
  const [tab, setTab] = useState<CaseTab>(routeTab)
  const [note, setNote] = useState<ClinicalNote>(state.clinicalNote ?? { id: 'note-1', status: 'draft', subjective: '', objective: '', assessment: '', plan: '', updatedAt: '' })
  const [noteError, setNoteError] = useState('')
  const [noteDirty, setNoteDirty] = useState(false)
  const [noteMessage, setNoteMessage] = useState('')
  const [signConfirm, setSignConfirm] = useState(false)
  const [published, setPublished] = useState(state.carePlan?.status === 'published')
  const [publishConfirm, setPublishConfirm] = useState(false)
  const [publishMessage, setPublishMessage] = useState('')
  const [planDraft, setPlanDraft] = useState<CarePlanDraft>({
    title: state.carePlan?.title ?? '舒适含乳 · 7 天支持计划',
    goals: state.carePlan?.goals.join('、') ?? '减少含乳疼痛、建立可持续节奏',
    summary: state.carePlan?.summary ?? '先让喂养变得更舒服，再观察节奏的变化。我们每次只做一个小调整。'
  })
  const navigate = useNavigate()
  const noteReady = Boolean(state.clinicalNote && state.clinicalNote.status !== 'draft')
  const providerName = providerShortName(state)
  const casePath = fromDailyFollowup ? `/ibclc/daily-followup/${caseId}` : fromAppointments ? `/ibclc/appointments/${caseId}` : location.pathname.startsWith('/ibclc/clients/') ? `/ibclc/clients/${caseId}` : `/ibclc/cases/${caseId}`
  const demoCase = demoSecondaryCases.find((item) => item.id === caseId)
  const selectedAppointment = state.appointment && (state.appointment.episodeId === `episode-demo-${caseId}` || (!state.appointment.episodeId.startsWith('episode-demo-') && caseId === 'mia'))
    ? state.appointment
    : state.appointments.find((appointment) => appointment.episodeId === `episode-demo-${caseId}`)
  const baseCurrentCase = getCaseQueue(state).find((item) => item.id === 'mia')
  const selectedProviderService = providerServices.find((service) => service.episodeId === selectedServiceId)
    ?? providerServices.find((service) => service.episodeId === state.episode?.id)
    ?? providerServices[0]
  const currentCase = baseCurrentCase && selectedProviderService ? {
    ...baseCurrentCase,
    purchasedAt: selectedProviderService.purchasedAt,
    servicePackage: selectedProviderService.packageName,
    serviceDay: selectedProviderService.serviceDay,
    serviceDaysTotal: selectedProviderService.serviceDaysTotal,
    serviceStartedAt: selectedProviderService.startedAt,
    consultationsUsed: selectedProviderService.consultationsUsed,
    consultationsTotal: selectedProviderService.consultationsTotal,
    remainingSessions: Math.max(0, selectedProviderService.consultationsTotal - selectedProviderService.consultationsUsed),
    nextConsultation: selectedProviderService.nextConsultation,
    cycleEnd: new Date(selectedProviderService.endsAt).toLocaleDateString('zh-CN'),
  } : baseCurrentCase
  const serviceAppointment = selectedProviderService
    ? (state.appointment?.episodeId === selectedProviderService.episodeId ? state.appointment : undefined)
      ?? state.appointments.find((appointment) => appointment.episodeId === selectedProviderService.episodeId && (!appointment.ibclcId || appointment.ibclcId === state.workbenchAssignment.ibclcId))
    : selectedAppointment

  if (fromAppointments && routeTab === 'overview' && selectedAppointment) {
    return <AppointmentPrepOverview state={state} appointment={selectedAppointment} item={demoCase} onBack={() => navigate('/ibclc/appointments')} />
  }

  if (demoCase && state.appointments.some((item) => item.id.startsWith('appt-demo-'))) {
    return <DemoCaseOverview item={{ ...demoCase, owner: providerName }} appointment={selectedAppointment} fromAppointments={fromAppointments} onBack={() => navigate(returnPath)} />
  }

  if (caseId !== 'mia' || !state.episode) {
    return <div className="work-page"><button className="back-button" onClick={() => navigate(returnPath)}>{returnLabel}</button><Card><EmptyState title="找不到这个病例" body="病例可能已被移出当前分配范围。返回上一级查看可处理内容。" action={<Button size="sm" onClick={() => navigate(returnPath)}>{returnLabel}</Button>} /></Card></div>
  }

  const updateNote = (next: ClinicalNote) => { setNote({ ...next, status: next.status === 'signed' ? 'signed' : 'draft' }); setNoteDirty(true); setNoteMessage('') }
  const saveDraft = () => {
    const draft: ClinicalNote = { ...note, status: 'draft', updatedAt: new Date().toISOString() }
    setNote(draft)
    setNoteDirty(false)
    setNoteMessage('草稿已保存 · 仅你可见')
    dispatch({ type: 'saveNote', note: draft })
  }
  const requestSign = () => {
    if (![note.subjective, note.objective, note.assessment, note.plan].every((value) => value.trim())) {
      setNoteError('请先完成四个字段，再签署这条记录。草稿仍会保留。')
      setSignConfirm(false)
      return
    }
    setNoteError('')
    setSignConfirm(true)
  }
  const confirmSign = () => {
    const signed: ClinicalNote = { ...note, status: 'signed', updatedAt: new Date().toISOString() }
    setNote(signed)
    setNoteDirty(false)
    setSignConfirm(false)
    setNoteMessage('已签署 · 记录现为只读')
    dispatch({ type: 'saveNote', note: signed })
  }
  const publishPlan = () => {
    const publishedAt = new Date()
    const tasks = [
      { id: 'task-1', title: '尝试半躺式含乳', description: '下一次喂养时观察舒适度。', category: '喂养', dueLabel: '今天', scheduledDate: dateKey(publishedAt), status: 'pending' as const, sourceKey: 'latch-position' },
      { id: 'task-2', title: '记录 2 次舒适度', description: '用 1–5 分记录喂养前后舒适度，不需要追求完整。', category: '观察', dueLabel: '明天', scheduledDate: dateKey(addDays(publishedAt, 1)), status: 'pending' as const, sourceKey: 'comfort-log' },
      { id: 'task-3', title: '完成 7 天复盘记录', description: '下次咨询前记录舒适度变化和执行反馈。', category: '复盘', dueLabel: '本周内', scheduledDate: dateKey(addDays(publishedAt, 6)), status: 'pending' as const, sourceKey: 'followup-review' }
    ]
    const goals = planDraft.goals.split(/[、,，]/).map((goal) => goal.trim()).filter(Boolean)
    const plan: CarePlan = { id: 'plan-1', version: (state.carePlan?.version ?? 0) + 1, status: 'published', title: planDraft.title.trim() || '本次行动计划', summary: planDraft.summary.trim() || '先完成一个小调整，再观察变化。', goals: goals.length ? goals : ['观察下一次喂养的真实感受'], publishedAt: publishedAt.toISOString(), tasks }
    dispatch({ type: 'publishCarePlan', plan })
    setPublished(true)
    setPublishConfirm(false)
    setPublishMessage('已发布 · 3 个行动任务已加入用户日程')
  }
  const selectTab = (next: CaseTab) => {
    setTab(next)
    if (fromDailyFollowup) {
      const path = next === 'daily' ? '' : next === 'consultation' ? '/online-consultation' : next === 'plan' ? '/care-plan' : '/overview'
      navigate(`${casePath}${path}${location.search}`)
    }
    else if (next !== 'overview') goToCaseTab(navigate, next, casePath)
    else navigate(casePath)
  }
  return <div className="work-page case-page">
    <button className="back-button" onClick={() => navigate(returnPath)}>{returnLabel}</button>
    <ClientDetailProfile initials={state.user.avatar} name={state.user.name} postpartumLabel={formatPostpartumDay(state.user.postpartumDay)} stateCode={state.user.state} providerName={providerName} services={providerServices} selectedServiceId={selectedProviderService?.episodeId} onSelectService={(episodeId) => { setSelectedServiceId(episodeId); selectTab(fromDailyFollowup ? 'daily' : 'overview') }} />
    <div className="case-tabs" role="tablist" aria-label="客户服务工作区"><button role="tab" aria-selected={tab === 'overview'} className={tab === 'overview' ? 'active' : ''} onClick={() => selectTab('overview')}>概览</button><button role="tab" aria-selected={tab === 'daily'} className={tab === 'daily' ? 'active' : ''} onClick={() => selectTab('daily')}>今日跟进</button><button role="tab" aria-selected={tab === 'consultation'} className={tab === 'consultation' ? 'active' : ''} onClick={() => selectTab('consultation')}>在线咨询</button><button role="tab" aria-selected={tab === 'plan'} className={tab === 'plan' ? 'active' : ''} onClick={() => selectTab('plan')}>Care Plan{published && <span className="tab-dot" />}</button></div>
    {tab === 'overview' && currentCase && <ServiceCycleOverview item={currentCase} onOpenDaily={() => selectTab('daily')} onOpenConsultation={() => selectTab('consultation')} />}
    {tab === 'daily' && currentCase && <DailyFollowupPanel item={currentCase} />}
    {tab === 'consultation' && currentCase && (showClinicalNote
      ? <><button className="back-button consultation-back" onClick={() => selectTab('consultation')}>返回在线咨询</button><NotePanel note={note} setNote={updateNote} saveDraft={saveDraft} requestSign={requestSign} confirmSign={confirmSign} cancelSign={() => setSignConfirm(false)} error={noteError} message={noteMessage} dirty={noteDirty} confirmingSign={signConfirm} /></>
      : <><OnlineConsultationPanel item={currentCase} appointment={serviceAppointment} onOpenNote={() => goToCaseTab(navigate, 'note', casePath)} onOpenRoom={() => serviceAppointment && navigate(`/ibclc/appointments/${serviceAppointment.id}/room`)} onOpenSchedule={() => navigate('/ibclc/availability')} /><ConsultationPrepCards profile={primaryConsultationPrepProfile(state)} includeAiSummary={false} /><CaseIntelligenceModules state={state} />{state.intake.riskLevel !== 'R0' && <Card className="risk-card"><p className="eyebrow">需要复核</p><div className="safety-line"><StatusDot tone={riskTone(state.intake.riskLevel)} /><span>请确认是否需要升级或转介</span><Badge tone={riskTone(state.intake.riskLevel)}>{state.intake.riskLevel}</Badge></div></Card>}</>)}
    {tab === 'plan' && <CarePlanPanel plan={state.carePlan} draft={planDraft} setDraft={setPlanDraft} published={published} canPublish={noteReady} publishConfirm={publishConfirm} publishMessage={publishMessage} requestPublish={() => setPublishConfirm(true)} confirmPublish={publishPlan} cancelPublish={() => setPublishConfirm(false)} />}
  </div>
}

function NotePanel({ note, setNote, saveDraft, requestSign, confirmSign, cancelSign, error, message, dirty, confirmingSign }: { note: ClinicalNote; setNote: (note: ClinicalNote) => void; saveDraft: () => void; requestSign: () => void; confirmSign: () => void; cancelSign: () => void; error?: string; message?: string; dirty: boolean; confirmingSign: boolean }) {
  const fields = [['subjective', 'S · 主观描述', '用户原话'], ['objective', 'O · 客观观察', '观察'], ['assessment', 'A · 专业评估', '评估'], ['plan', 'P · 行动计划', '下一步']] as const
  const signed = note.status === 'signed' || note.status === 'amended' || note.status === 'locked'
  return <div className="editor-layout single-column"><Card className="editor-card"><div className="editor-header"><div><p className="eyebrow">{signed ? '已签署 · 只读' : '专业记录'}</p><h2>Clinical Note</h2><p className="editor-subtitle">本次咨询的专业判断与下一步。</p></div><div className="editor-header-actions"><Badge tone={signed ? 'green' : 'amber'}>{signed ? 'Signed' : 'Draft'}</Badge>{!signed && <><Button variant="soft" size="sm" onClick={saveDraft} disabled={!dirty}>保存草稿</Button><Button size="sm" onClick={requestSign}>签署记录</Button></>}</div></div>{(message || dirty) && <div className={`editor-save-state ${dirty ? 'unsaved' : 'saved'}`} aria-live="polite"><Icon name={dirty ? 'clock' : 'check'} /><span>{dirty ? '有未保存修改' : message}</span></div>}{error && <div className="inline-error" role="alert"><Icon name="note" />{error}</div>}{confirmingSign && <div className="sign-confirmation" role="alert"><div><strong>确认签署这条记录？</strong><p>签署后内容会变为只读；如需修改，应创建新的修订版本。</p></div><div><button className="text-button" onClick={cancelSign}>返回编辑</button><Button size="sm" onClick={confirmSign}>确认签署</Button></div></div>}{signed && <div className="editor-locked"><Icon name="lock" /><span>已签署记录不可直接编辑，修改请走修订流程。</span></div>}{fields.map(([key, label, placeholder]) => <label className="editor-field" key={key}><span>{label}</span><textarea aria-label={label} value={note[key]} disabled={signed} onChange={(event) => setNote({ ...note, [key]: event.target.value })} placeholder={placeholder} rows={key === 'subjective' ? 4 : 3} /></label>)}</Card></div>
}

function CarePlanPanel({ plan, draft, setDraft, published, canPublish, publishConfirm, publishMessage, requestPublish, confirmPublish, cancelPublish }: { plan?: CarePlan; draft: CarePlanDraft; setDraft: (draft: CarePlanDraft) => void; published: boolean; canPublish: boolean; publishConfirm: boolean; publishMessage: string; requestPublish: () => void; confirmPublish: () => void; cancelPublish: () => void }) {
  const tasks = plan?.tasks ?? [
    { id: 'draft-1', title: '尝试半躺式含乳', description: '下一次喂养时观察舒适度。', category: '喂养', dueLabel: '今天', status: 'pending' as const, sourceKey: 'draft-latch-position' },
    { id: 'draft-2', title: '记录 2 次舒适度', description: '用 1–5 分记录喂养前后舒适度，不需要追求完整。', category: '观察', dueLabel: '明天', status: 'pending' as const, sourceKey: 'draft-comfort-log' },
    { id: 'draft-3', title: '完成 7 天复盘记录', description: '下次咨询前记录舒适度变化和执行反馈。', category: '复盘', dueLabel: '本周内', status: 'pending' as const, sourceKey: 'draft-followup-review' }
  ]
  return <div className="plan-editor-layout single-column">
    <Card className="plan-editor">
      <div className="editor-header"><div><p className="eyebrow">方案</p><h2>Care Plan</h2><p className="editor-subtitle">把专业判断拆成用户今天能完成的动作。</p></div><div className="editor-header-actions"><Badge tone={published ? 'green' : 'amber'}>{published ? `v${plan?.version} · 已发布` : 'Draft'}</Badge><Button size="sm" onClick={requestPublish} disabled={!canPublish} title={!canPublish ? '签署 Clinical Note 后才能发布' : undefined}>{published ? '发布新版本' : '发布方案'}</Button></div></div>
      {publishConfirm && <div className="publish-confirmation" role="alert"><div><strong>发布这版 Care Plan？</strong><p>发布会在用户日程中生成 {tasks.length} 个行动任务，并保留当前版本记录。</p></div><div><button className="text-button" onClick={cancelPublish}>取消</button><Button size="sm" onClick={confirmPublish}>确认发布</Button></div></div>}
      {publishMessage && <div className="inline-success" role="status"><Icon name="check" /><span>{publishMessage}</span></div>}
      <div className="form-grid"><label><span>方案标题</span><input aria-label="方案标题" value={draft.title} onChange={(event) => setDraft({ ...draft, title: event.target.value })} /></label><label><span>服务目标</span><input aria-label="服务目标" value={draft.goals} onChange={(event) => setDraft({ ...draft, goals: event.target.value })} /></label></div>
      <label className="editor-field"><span>给用户的总结</span><textarea aria-label="给用户的总结" value={draft.summary} onChange={(event) => setDraft({ ...draft, summary: event.target.value })} rows={3} /></label>
      <SectionTitle title="行动任务" action={<span className="section-count">{tasks.length} 项</span>} />
      <div className="work-task-list">{tasks.map((task) => <div className="work-task" key={task.id}><div className={`task-check ${task.status === 'completed' ? 'checked' : ''}`}>{task.status === 'completed' ? <Icon name="check" /> : ''}</div><div><strong>{task.title}</strong><p>{task.description}</p></div><Badge tone={task.status === 'completed' ? 'green' : 'neutral'}>{task.dueLabel}</Badge></div>)}</div>
    </Card>
  </div>
}

function blankDocumentationNote(): ClinicalNote {
  return {
    id: 'new-note',
    status: 'draft',
    version: 0,
    subjective: '',
    objective: '',
    assessment: '',
    plan: '',
    updatedAt: '',
  }
}

function blankPlanTask(index: number): CareTask {
  return {
    id: `draft-task-${index}`,
    sourceKey: `action-${index}`,
    title: '',
    description: '',
    category: '喂养',
    dueLabel: index === 1 ? '今天' : '本周内',
    status: 'pending',
  }
}

function blankDocumentationPlan(appointmentId: string): CarePlan {
  return {
    id: `draft-${appointmentId}`,
    version: 0,
    status: 'draft',
    title: '',
    summary: '',
    goals: [],
    tasks: [blankPlanTask(1)],
  }
}

function AppointmentDocumentationPage() {
  const { state, consultation, documentation } = useProduct()
  const { appointmentId = '' } = useParams()
  const navigate = useNavigate()
  const location = useLocation()
  const tab: 'note' | 'plan' = location.pathname.includes('care-plan') ? 'plan' : 'note'
  const appointment = state.appointments.find((item) => item.id === appointmentId)
  const record = documentation.records[appointmentId]
  const sourceNote = documentation.mode === 'server' ? record?.clinicalNote : state.clinicalNote
  const sourcePlan = documentation.mode === 'server' ? record?.carePlanDraft : state.carePlan
  const [note, setNote] = useState<ClinicalNote>(() => sourceNote ?? blankDocumentationNote())
  const [noteDirty, setNoteDirty] = useState(false)
  const [noteError, setNoteError] = useState('')
  const [noteMessage, setNoteMessage] = useState('')
  const [confirmingSign, setConfirmingSign] = useState(false)
  const [planDraft, setPlanDraft] = useState<CarePlan>(() => sourcePlan ?? blankDocumentationPlan(appointmentId))
  const [planDirty, setPlanDirty] = useState(false)
  const [planMessage, setPlanMessage] = useState('')
  const [planError, setPlanError] = useState('')

  useEffect(() => {
    if (!appointmentId || documentation.mode !== 'server') return
    if (!appointment) {
      void consultation.refreshAppointments()
      return
    }
    void documentation.load(appointment.id, 'ibclc')
  }, [appointment?.id, appointmentId, documentation.load, documentation.mode])

  useEffect(() => {
    if (!sourceNote || noteDirty) return
    setNote(sourceNote)
  }, [sourceNote?.version, noteDirty])

  useEffect(() => {
    if (!sourcePlan || planDirty) return
    setPlanDraft(sourcePlan)
  }, [sourcePlan?.version, planDirty])

  if (!appointment) {
    return <div className="work-page"><button className="back-button" onClick={() => navigate('/ibclc/appointments')}>返回预约列表</button><Card><EmptyState title={documentation.busy ? '正在读取预约' : '找不到这场预约'} body={documentation.busy ? '请稍候。' : '预约可能已取消，或不在你的分配范围内。'} action={<Button size="sm" onClick={() => void consultation.refreshAppointments()}>刷新预约</Button>} /></Card></div>
  }

  const patientName = appointmentPatientDisplayName(appointment, state)
  const updateNote = (next: ClinicalNote) => {
    setNote({ ...next, status: next.status === 'signed' ? 'signed' : 'draft' })
    setNoteDirty(true)
    setNoteMessage('')
  }
  const saveNote = async () => {
    const saved = await documentation.saveNote(appointment.id, note)
    if (!saved) return
    setNoteDirty(false)
    setNoteMessage('草稿已保存 · 仅你可见')
  }
  const requestSign = () => {
    if (![note.subjective, note.objective, note.assessment, note.plan].every((value) => value.trim())) {
      setNoteError('请先完成四个字段，再签署这条记录。草稿仍会保留。')
      return
    }
    setNoteError('')
    setConfirmingSign(true)
  }
  const signNote = async () => {
    const signed = await documentation.signNote(appointment.id, note)
    if (!signed) return
    setNoteDirty(false)
    setConfirmingSign(false)
    setNoteMessage('已签署 · 记录现为只读')
  }
  const updatePlan = (changes: Partial<CarePlan>) => {
    setPlanDraft((current) => ({ ...current, ...changes, status: 'draft' }))
    setPlanDirty(true)
    setPlanMessage('')
  }
  const updateTask = (index: number, changes: Partial<CareTask>) => {
    updatePlan({
      tasks: planDraft.tasks.map((task, taskIndex) => taskIndex === index ? { ...task, ...changes } : task),
    })
  }
  const validatePlan = () => {
    if (!planDraft.title.trim() || !planDraft.summary.trim() || !planDraft.goals.some((goal) => goal.trim())) {
      setPlanError('请填写方案标题、给用户的总结和至少一个观察目标。')
      return false
    }
    if (!planDraft.tasks.length || planDraft.tasks.some((task) => !task.title.trim() || !task.description.trim() || !task.category.trim() || !task.dueLabel.trim())) {
      setPlanError('请完整填写至少一个行动任务。')
      return false
    }
    setPlanError('')
    return true
  }
  const savePlan = async () => {
    if (!validatePlan()) return
    const saved = await documentation.savePlan(appointment.id, planDraft)
    if (!saved) return
    setPlanDirty(false)
    setPlanMessage('Care Plan 草稿已保存 · 用户暂不可见')
  }
  const publishPlan = async () => {
    if (!validatePlan()) return
    const published = await documentation.publishPlan(appointment.id, planDraft)
    if (!published) return
    setPlanDirty(false)
    setPlanMessage('已发布 · 用户现在可以查看本次总结')
  }
  const noteReady = sourceNote?.status === 'signed' || note.status === 'signed'
  const publishedPlan = record?.currentPublication ?? (documentation.mode === 'browser_mock' ? state.carePlan : undefined)

  return <div className="work-page case-page appointment-documentation-page">
    <button className="back-button" onClick={() => navigate('/ibclc/appointments')}>返回预约列表</button>
    <div className="work-heading"><div><p className="eyebrow">{appointment.serviceName ?? '视频咨询'} · 咨询后记录</p><h1>{patientName}</h1><p>{formatAppointmentDayLabel(appointment.start, appointment.timezone)} · {formatAppointmentTime(appointment.start, appointment.timezone)}–{formatAppointmentTime(appointment.end, appointment.timezone)}</p></div><Badge tone={publishedPlan ? 'green' : noteReady ? 'blue' : 'amber'}>{publishedPlan ? '总结已发布' : noteReady ? '记录已签署' : '待完成记录'}</Badge></div>
    <div className="case-tabs" role="tablist" aria-label="咨询后记录"><button role="tab" aria-selected={tab === 'note'} className={tab === 'note' ? 'active' : ''} onClick={() => navigate(`/ibclc/appointments/${appointment.id}/clinical-note`)}>Clinical Note</button><button role="tab" aria-selected={tab === 'plan'} className={tab === 'plan' ? 'active' : ''} onClick={() => navigate(`/ibclc/appointments/${appointment.id}/care-plan`)}>给用户的 Care Plan</button></div>
    {documentation.error && <div className="inline-error" role="alert"><Icon name="note" />{documentation.error}<button className="text-button" onClick={() => void documentation.load(appointment.id, 'ibclc')}>重新加载</button></div>}
    {tab === 'note' ? <NotePanel note={note} setNote={updateNote} saveDraft={() => void saveNote()} requestSign={requestSign} confirmSign={() => void signNote()} cancelSign={() => setConfirmingSign(false)} error={noteError} message={noteMessage} dirty={noteDirty} confirmingSign={confirmingSign} /> : <div className="plan-editor-layout"><Card className="plan-editor"><div className="editor-header"><div><p className="eyebrow">妈妈端可见</p><h2>Care Plan</h2><p className="editor-subtitle">把共同确认的重点整理成今天能开始的小行动。</p></div><div className="editor-header-actions"><Badge tone={publishedPlan ? 'green' : 'amber'}>{publishedPlan ? `v${publishedPlan.version} · 已发布` : 'Draft'}</Badge><Button variant="soft" size="sm" disabled={!planDirty || documentation.busy} onClick={() => void savePlan()}>{documentation.busy ? '正在保存…' : '保存草稿'}</Button><Button size="sm" disabled={!noteReady || documentation.busy} onClick={() => void publishPlan()}>{documentation.busy ? '正在发布…' : publishedPlan ? '发布新版本' : '发布给用户'}</Button></div></div>{!noteReady && <div className="inline-warning"><Icon name="note" /><span>签署 Clinical Note 后才能发布；Care Plan 草稿仍可保存。</span><button className="text-button" onClick={() => navigate(`/ibclc/appointments/${appointment.id}/clinical-note`)}>去签署 <Icon name="arrow" /></button></div>}{(planError || planMessage) && <div className={planError ? 'inline-error' : 'inline-success'} role={planError ? 'alert' : 'status'}><Icon name={planError ? 'note' : 'check'} />{planError || planMessage}</div>}<div className="form-grid"><label><span>方案标题</span><input aria-label="方案标题" value={planDraft.title} onChange={(event) => updatePlan({ title: event.target.value })} placeholder="例如：未来 7 天的舒适喂养计划" /></label><label><span>观察目标</span><input aria-label="观察目标" value={planDraft.goals.join('、')} onChange={(event) => updatePlan({ goals: event.target.value.split(/[、,，]/).map((goal) => goal.trim()).filter(Boolean) })} placeholder="用顿号分隔，最多 6 项" /></label></div><label className="editor-field"><span>给用户的总结</span><textarea aria-label="给用户的总结" value={planDraft.summary} onChange={(event) => updatePlan({ summary: event.target.value })} rows={4} placeholder="先回应用户最关心的事，再说明接下来可以怎么做。" /></label><SectionTitle title="行动任务" action={<Button size="sm" variant="soft" disabled={planDraft.tasks.length >= 6} onClick={() => updatePlan({ tasks: [...planDraft.tasks, blankPlanTask(planDraft.tasks.length + 1)] })}>添加任务</Button>} /><div className="documentation-task-editor">{planDraft.tasks.map((task, index) => <div className="documentation-task-row" key={task.id}><div className="documentation-task-number">{index + 1}</div><div className="documentation-task-fields"><input aria-label={`任务 ${index + 1} 标题`} value={task.title} onChange={(event) => updateTask(index, { title: event.target.value })} placeholder="行动名称" /><textarea aria-label={`任务 ${index + 1} 说明`} value={task.description} onChange={(event) => updateTask(index, { description: event.target.value })} rows={2} placeholder="说明怎么做，以及要留意什么" /><div><input aria-label={`任务 ${index + 1} 分类`} value={task.category} onChange={(event) => updateTask(index, { category: event.target.value })} placeholder="分类" /><input aria-label={`任务 ${index + 1} 时间`} value={task.dueLabel} onChange={(event) => updateTask(index, { dueLabel: event.target.value })} placeholder="例如：今天" /></div></div>{planDraft.tasks.length > 1 && <button className="text-button documentation-task-remove" onClick={() => updatePlan({ tasks: planDraft.tasks.filter((_, taskIndex) => taskIndex !== index) })}>移除</button>}</div>)}</div></Card><details className="version-disclosure"><summary><span><p className="eyebrow">发布状态</p><strong>{publishedPlan ? `v${publishedPlan.version} · 用户可见` : '尚未发布'}</strong></span><span className="details-chevron">⌄</span></summary><p>保存草稿不会通知用户；只有点击“发布给用户”后，妈妈端才会看到这份内容。</p></details></div>}
    {tab === 'plan' && publishedPlan && <Card className="published-task-progress"><div className="published-task-progress-heading"><div><p className="eyebrow">用户执行进度</p><h2>{publishedPlan.tasks.filter((task) => task.status === 'completed').length}/{publishedPlan.tasks.length} 项已完成</h2></div><Badge tone="green">v{publishedPlan.version} · 实时</Badge></div><div className="published-task-progress-list">{publishedPlan.tasks.map((task) => <div key={task.id}><span className={`published-task-progress-mark ${task.status}`}><Icon name={task.status === 'completed' ? 'check' : 'clock'} /></span><span><strong>{task.title}</strong><small>{task.dueLabel}</small></span><Badge tone={task.status === 'completed' || task.status === 'in_progress' ? 'green' : 'neutral'}>{task.status === 'completed' ? '已完成' : task.status === 'in_progress' ? '进行中' : task.status === 'skipped' ? '已跳过' : '待完成'}</Badge></div>)}</div></Card>}
  </div>
}

function FollowupPanel({ navigate }: { navigate: (to: string) => void }) {
  const [referral, setReferral] = useState(false)
  const [sent, setSent] = useState(false)
  return <div className="followup-layout"><Card><SectionTitle title="下一步" /><div className="followup-item"><div className="followup-icon"><Icon name="calendar" /></div><div><strong>预约 7 天复盘</strong><p>沿用当前服务周期，不新建孤立咨询。</p></div><Button size="sm" onClick={() => navigate('/ibclc/appointments')}>安排</Button></div><div className="followup-item"><div className="followup-icon"><Icon name="send" /></div><div><strong>发送提醒</strong><p>{sent ? '提醒已记录到演示时间线。' : '发送一条关于任务执行的简短提醒。'}</p></div><Button size="sm" variant="soft" onClick={() => setSent(true)}>{sent ? '已发送' : '发送'}</Button></div><div className="followup-item"><div className="followup-icon"><Icon name="shield" /></div><div><strong>创建转介</strong><p>超出 IBCLC 范围或出现高风险信号时使用。</p></div><Button size="sm" variant={referral ? 'soft' : 'secondary'} onClick={() => setReferral(!referral)}>{referral ? '已记录' : '创建'}</Button></div></Card>{referral && <Card className="referral-work-card"><Badge tone="amber">待确认</Badge><h3>建议联系儿科服务提供者</h3><p>确认后才会通知相关人员；演示状态不会发送真实消息。</p><Button size="sm" onClick={() => setReferral(false)}>确认并记录</Button></Card>}</div>
}

function PreConsultPage() {
  const state = useWorkbenchState()
  const navigate = useNavigate()
  const activeBabyFeedingCount = state.feedingRecords.filter((record) => record.babyId === state.baby.id && record.type !== '泵奶').length
  return <div className="work-page preconsult-page"><button className="back-button" onClick={() => navigate('/ibclc/cases/mia')}>返回病例</button><div className="work-heading"><div><p className="eyebrow">咨询前 · CASE-001</p><h1>咨询前摘要</h1></div><Button onClick={() => state.appointment ? navigate(`/ibclc/appointments/${state.appointment.id}/room`) : navigate('/ibclc/appointments')}><Icon name="video" /> 进入咨询室</Button></div><div className="preconsult-grid"><Card><p className="eyebrow">目标</p><h2>让喂养更舒服、更有节奏</h2><div className="goal-chips"><Badge tone="rose">{state.intake.symptoms.join(' · ')}</Badge><Badge tone="blue">{state.intake.feedingGoal}</Badge></div><p className="case-quote">“{state.intake.supportNeeded}”</p></Card><Card><p className="eyebrow">{state.baby.name} 的近期记录</p><div className="preconsult-stat"><strong>{activeBabyFeedingCount || '—'}</strong><span>条喂养记录</span></div></Card><Card><p className="eyebrow">计划</p>{state.carePlan ? <h3>{state.carePlan.tasks.filter((task) => task.status !== 'completed').length} 个待反馈</h3> : <h3>尚未发布</h3>}</Card><Card><p className="eyebrow">安全</p><div className="safety-line"><StatusDot tone={riskTone(state.intake.riskLevel)} /><span>{riskLabel(state.intake.riskLevel)} · Consent {state.consent.status === 'active' ? '有效' : '待确认'}</span></div></Card></div><Card className="ai-summary-card"><div className="assistant-mark"><img src={cozymateAvatar} alt="" /></div><div><Badge tone="blue">Cozymate 草稿</Badge><h3>关注含乳舒适度与夜间节奏</h3></div><Button variant="soft" onClick={() => navigate('/ibclc/cases/mia/clinical-note')}>打开 Note</Button></Card></div>
}

function SchedulePage() {
  const state = useWorkbenchState()
  const [selectedDate, setSelectedDate] = useState(() => dateKey(new Date()))
  const bookedStatuses = new Set<AppointmentStatus>(['confirmed', 'in_progress', 'completed', 'no_show', 'conflict'])
  const appointmentSource = state.appointment ? [...state.appointments, state.appointment] : state.appointments
  const appointmentRows: ScheduleRow[] = Array.from(new Map(appointmentSource.map((appointment) => [appointment.id, appointment])).values())
    .filter((appointment) => bookedStatuses.has(appointment.status) && (!appointment.ibclcId || appointment.ibclcId === state.workbenchAssignment.ibclcId))
    .map((appointment) => ({
      id: appointment.id,
      start: appointment.start,
      end: appointment.end,
      timezone: appointment.timezone,
      title: appointmentPatientDisplayName(appointment, state),
      subtitle: appointment.serviceName ?? '视频咨询',
      statusLabel: appointmentStatus(appointment.status).label,
    }))
  const sortedRows = [...appointmentRows].sort((a, b) => new Date(a.start).getTime() - new Date(b.start).getTime())
  const calendarStart = useMemo(() => startOfWeek(parseLocalDate(selectedDate)), [selectedDate])
  const calendarEnd = addDays(calendarStart, 6)
  const calendarDays = useMemo(() => Array.from({ length: 7 }, (_, index) => {
    const day = addDays(calendarStart, index)
    const key = dateKey(day)
    return {
      key,
      date: day,
      weekday: formatCalendarWeekday(day),
      label: formatCalendarDate(day),
      isToday: key === dateKey(new Date()),
      isSelected: key === selectedDate
    }
  }), [calendarStart, selectedDate])
  const weekStartKey = dateKey(calendarStart)
  const weekEndKey = dateKey(calendarEnd)
  const weekRows = sortedRows.filter((row) => {
    const key = appointmentDateKey(row.start, row.timezone)
    return key >= weekStartKey && key <= weekEndKey
  })
  const currentWeekStart = startOfWeek(new Date())
  const currentWeekStartKey = dateKey(currentWeekStart)
  const currentWeekEndKey = dateKey(addDays(currentWeekStart, 6))
  const currentWeekRows = sortedRows.filter((row) => {
    const key = appointmentDateKey(row.start, row.timezone)
    return key >= currentWeekStartKey && key <= currentWeekEndKey
  })
  const currentWeekAppointmentCount = currentWeekRows.length
  const groupedVisible = useMemo(() => {
    const map = new Map<string, ScheduleRow[]>()
    for (const row of weekRows) {
      const key = appointmentDateKey(row.start, row.timezone)
      const bucket = map.get(key) ?? []
      bucket.push(row)
      map.set(key, bucket)
    }
    return map
  }, [weekRows])
  const monthAnchor = useMemo(() => parseLocalDate(selectedDate), [selectedDate])
  const monthDays = useMemo(() => calendarMonthDays(monthAnchor), [monthAnchor])
  const calendarHours = Array.from({ length: 13 }, (_, index) => index + 8)
  const calendarRangeLabel = formatCalendarRange(calendarStart, calendarEnd)
  const shiftMonth = (amount: number) => setSelectedDate((value) => dateKey(addMonths(parseLocalDate(value), amount)))
  const selectMonthDay = (day: Date) => setSelectedDate(dateKey(day))
  const timelineStart = 8 * 60
  const timelineTotal = 12 * 60
  const eventPosition = (row: ScheduleRow) => {
    const start = minutesSinceMidnight(row.start, row.timezone)
    const end = minutesSinceMidnight(row.end, row.timezone)
    const top = Math.max(0, Math.min(100, ((start - timelineStart) / timelineTotal) * 100))
    const height = Math.max(7, Math.min(100 - top, ((Math.max(15, end - start) / timelineTotal) * 100)))
    return { top: `${top}%`, height: `${height}%` }
  }
  return <div className="work-page schedule-page">
    <div className="work-heading"><div className="work-heading-copy"><h1>日程管理</h1><p className="work-heading-subtitle">通过日历查看已排定的客户咨询。</p></div></div>
    <Card className="schedule-calendar-card">
      <div className="schedule-calendar-toolbar">
        <div className="schedule-range"><strong>{calendarRangeLabel}</strong></div>
      </div>
      <div className="schedule-calendar-layout">
        <aside className="schedule-calendar-sidebar" aria-label="月份导航">
          <div className="schedule-month-heading">
            <strong>{formatMonthHeading(monthAnchor)}</strong>
            <div className="schedule-month-actions">
              <button aria-label="上个月" onClick={() => shiftMonth(-1)}>‹</button>
              <button aria-label="下个月" onClick={() => shiftMonth(1)}>›</button>
            </div>
          </div>
          <div className="schedule-month-weekdays" aria-hidden="true">{['一', '二', '三', '四', '五', '六', '日'].map((label) => <span key={label}>{label}</span>)}</div>
          <div className="schedule-month-grid">{monthDays.map((day) => { const key = dateKey(day); const inMonth = day.getMonth() === monthAnchor.getMonth(); const inSelectedWeek = key >= weekStartKey && key <= weekEndKey; return <button key={key} className={`${inMonth ? '' : 'outside'} ${inSelectedWeek ? 'in-selected-week' : ''} ${key === dateKey(new Date()) ? 'today' : ''} ${key === selectedDate ? 'selected' : ''}`} aria-label={key} onClick={() => selectMonthDay(day)}>{day.getDate()}</button> })}</div>
          <div className="schedule-sidebar-summary"><p className="eyebrow">本周安排</p><div><strong>{currentWeekAppointmentCount}</strong><span>场预约</span></div></div>
        </aside>
        <div className="schedule-calendar-scroll">
          <div className="schedule-timeline-layout" role="grid" aria-label="我的日程周视图">
            <div className="schedule-time-axis"><div className="schedule-timezone">本地时间</div><div className="schedule-time-labels">{calendarHours.map((hour) => <span key={hour}>{String(hour).padStart(2, '0')}:00</span>)}</div></div>
            <div className="schedule-timeline-main">
              <div className="schedule-day-headings">{calendarDays.map((day) => { const dayRows = groupedVisible.get(day.key) ?? []; return <div key={day.key} className={`${day.isToday ? 'today' : ''} ${day.isSelected ? 'selected' : ''}`}><span>{day.weekday}</span><strong>{day.date.getDate()}</strong>{dayRows.length > 0 && <small>{dayRows.length}</small>}</div> })}</div>
              <div className="schedule-timeline-body">{calendarDays.map((day) => { const dayRows = groupedVisible.get(day.key) ?? []; return <div key={day.key} className={`schedule-timeline-column ${day.isToday ? 'today' : ''} ${day.isSelected ? 'selected' : ''}`}><div className="schedule-hour-lines" aria-hidden="true">{calendarHours.map((hour) => <span key={hour} />)}</div>{dayRows.map((row) => <article key={row.id} className="schedule-timeline-event" style={eventPosition(row)} aria-label={`${formatAppointmentTime(row.start, row.timezone)} 至 ${formatAppointmentTime(row.end, row.timezone)}，${row.title}，${row.statusLabel}`}><strong>{formatAppointmentTime(row.start, row.timezone)}–{formatAppointmentTime(row.end, row.timezone)}</strong><p>{row.title}</p><span>{row.subtitle} · {row.statusLabel}</span></article>)}</div> })}</div>
            </div>
          </div>
          {!weekRows.length && <div className="schedule-calendar-empty"><strong>本周没有预约</strong><span>点击左侧日期查看其他周的已预约咨询。</span></div>}
        </div>
      </div>
    </Card>
  </div>
}

function NotificationsPage() {
  const { dispatch } = useProduct()
  const state = useWorkbenchState()
  const workNotifications = getWorkbenchNotifications(state)
  const ordered = useMemo(() => [...workNotifications].sort((a, b) => Number(a.read) - Number(b.read) || Number(b.type === 'appointment') - Number(a.type === 'appointment')), [workNotifications])
  const appointmentReminders = ordered.filter((item) => item.type === 'appointment')
  const caseUpdates = ordered.filter((item) => item.type === 'system')
  const renderNotification = (item: typeof ordered[number]) => <Card key={item.id} className={`work-notification compact ${item.type} ${item.read ? 'read' : ''}`} onClick={() => dispatch({ type: 'markNotificationRead', id: item.id })}><div className={`notification-icon ${item.type}`}><Icon name={item.type === 'appointment' ? 'calendar' : 'note'} /></div><div><div className="notification-title-row"><div className="notification-title"><h3>{item.title}</h3></div>{!item.read && <Badge tone="rose">未读</Badge>}</div><p>{item.body}</p><span>{item.createdAt}</span></div></Card>
  return <div className="work-page notifications-page"><div className="work-heading"><div><h1>工作提醒</h1><p className="work-heading-subtitle">只显示需要你处理的预约、病例和服务事项。</p></div></div>{ordered.length ? <div className="work-notification-groups">{appointmentReminders.length > 0 && <section className="work-notification-group" aria-label="预约提醒"><div className="work-notification-list">{appointmentReminders.map(renderNotification)}</div></section>}{caseUpdates.length > 0 && <section className="work-notification-group"><SectionTitle title="病例与服务" /><div className="work-notification-list">{caseUpdates.map(renderNotification)}</div></section>}</div> : <Card className="work-reminder-empty"><div className="work-reminder-empty-icon"><Icon name="bell" /></div><div><h2>暂无工作提醒</h2><p>当前没有需要处理的预约变更、病例复核或服务跟进。</p></div></Card>}</div>
}

function SettingsPage() {
  const state = useWorkbenchState()
  const providerName = assignedProviderName(state)
  const initials = providerName.split(/[ ,]+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase()
  return <div className="work-page"><div className="work-heading"><div className="work-heading-copy"><p className="eyebrow">专家设置</p><h1>执业与权限</h1></div><Badge tone="green"><StatusDot tone="green" /> MFA 已开启</Badge></div><div className="settings-grid"><Card><SectionTitle title={providerName} /><div className="identity-line"><div className="provider-avatar">{initials}</div><div><strong>West Coast Care Team</strong><p>CA · 英语、中文</p></div></div><div className="setting-list"><div><span>执业州</span><Badge tone="green">CA</Badge></div><div><span>服务语言</span><Badge tone="blue">英语、中文</Badge></div><div><span>病例范围</span><Badge tone="green">已分配</Badge></div></div></Card><Card><SectionTitle title="当前权限" /><div className="checklist"><div><Icon name="check" /><span>查看已授权病例字段</span><Badge tone="green">可用</Badge></div><div><Icon name="check" /><span>签署 Clinical Note</span><Badge tone="green">可用</Badge></div><div><Icon name="check" /><span>发布 Care Plan</span><Badge tone="green">可用</Badge></div><div><Icon name="lock" /><span>导出 / 删除数据</span><Badge tone="amber">需确认</Badge></div></div><p className="settings-note">演示权限仅用于界面验证，不代表真实生产访问边界。</p></Card></div></div>
}

export default function Workbench() {
  return <WorkbenchShell><Routes>
    <Route path="daily-followup" element={<DailyFollowupsPage />} /><Route path="daily-followup/:caseId/*" element={<CasePage />} />
    <Route path="overview" element={<TodayAppointmentsPage />} /><Route path="dashboard" element={<TodayAppointmentsPage />} /><Route path="today" element={<TodayAppointmentsPage />} /><Route path="appointments" element={<TodayAppointmentsPage />} /><Route path="appointments/:appointmentId/room" element={<WorkbenchConsultationRoomPage />} /><Route path="appointments/:appointmentId/clinical-note" element={<AppointmentDocumentationPage />} /><Route path="appointments/:appointmentId/care-plan" element={<AppointmentDocumentationPage />} /><Route path="appointments/:caseId" element={<CasePage />} /><Route path="availability" element={<SchedulePage />} /><Route path="schedule" element={<SchedulePage />} /><Route path="cases" element={<CasesPage />} /><Route path="clients" element={<CasesPage />} /><Route path="cases/:caseId" element={<CasePage />} /><Route path="clients/:caseId" element={<CasePage />} /><Route path="appointments/:caseId/pre-consult" element={<PreConsultPage />} /><Route path="appointments/:caseId/pre-consult-summary" element={<PreConsultPage />} /><Route path="appointments/:caseId/follow-ups" element={<CasePage />} /><Route path="cases/:caseId/pre-consult" element={<PreConsultPage />} /><Route path="cases/:caseId/pre-consult-summary" element={<PreConsultPage />} /><Route path="cases/:caseId/daily-followup" element={<CasePage />} /><Route path="cases/:caseId/online-consultation" element={<CasePage />} /><Route path="cases/:caseId/clinical-note" element={<CasePage />} /><Route path="cases/:caseId/care-plan" element={<CasePage />} /><Route path="cases/:caseId/follow-ups" element={<CasePage />} /><Route path="clients/:caseId/pre-consult" element={<PreConsultPage />} /><Route path="clients/:caseId/pre-consult-summary" element={<PreConsultPage />} /><Route path="clients/:caseId/daily-followup" element={<CasePage />} /><Route path="clients/:caseId/online-consultation" element={<CasePage />} /><Route path="clients/:caseId/clinical-note" element={<CasePage />} /><Route path="clients/:caseId/care-plan" element={<CasePage />} /><Route path="clients/:caseId/follow-ups" element={<CasePage />} /><Route path="notifications" element={<NotificationsPage />} /><Route path="settings" element={<SettingsPage />} /><Route path="*" element={<TodayAppointmentsPage />} />
    <Route path="clients/remote/:clientId" element={<ServerClientPage />} />
  </Routes></WorkbenchShell>
}
