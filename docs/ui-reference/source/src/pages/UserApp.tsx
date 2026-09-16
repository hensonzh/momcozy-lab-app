import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { Link, Route, Routes, useLocation, useNavigate, useParams } from 'react-router-dom'
import { Badge, Button, Card, EmptyState, Icon, Modal, ProgressBar, SectionTitle, StatusDot } from '../components/UI'
import { MeExpertServiceCard, MeMilkTrend, MeSectionIcon, MeServiceTimeline, MeStatusCard, type MeServiceEvent } from '../components/MeOverview'
import { normalizeAgentMessages, useProduct } from '../store/ProductContext'
import { createAgentConversationId, createAgentMessageId, initialAgentRun, recoverInterruptedAgentRun } from '../store/agentSession'
import { getConsultationDisplayState } from '../features/consultation/session'
import { consultationAppointmentForRoute } from '../features/consultation/gateway'
import { consultationDevicesReady } from '../features/consultation/deviceCheck'
import { canEnterConsultationByTime, consultationCountdown, isConsultationDemo, preferredAppointmentForEpisode } from '../features/consultation/appointments'
import { buildAgentCommercialContext } from '../features/agent/commercialContext'
import { agentPreconsultPath, agentPreconsultPrompt } from '../features/agent/preconsult'
import { agentPostconsultPath, postconsultPrompt, postconsultStorageKey, shouldHandOffConsultation } from '../features/agent/postconsult'
import { useRtcMedia } from '../features/consultation/rtcMedia'
import { rtcNetworkNotice } from '../features/consultation/rtcQuality'
import { demoServiceHistory } from '../features/consultation/demoServiceHistory'
import { babyAgeLabel, calendarMonthAgeInDays, growthRecordAgeInDays, WHO_GROWTH_MAX_MONTHS, whoGrowthReferencePoints } from '../features/baby/growthStandards'
import { formatPostpartumDay, postpartumStageForDay } from '../features/postpartum/stages'
import type { AgentConversation, AgentMessage, AgentMessageAttachment, AgentRunState, Appointment, AvailabilitySlot, BabyDevelopmentStatus, BabyGrowthMetric, BabyGrowthRecord, BabySex, BabyStoolColor, BabyStoolConsistency, BabyStoolVisibleSign, CarePlan, CareTask, FeedingRecord, LactationMethod, LactationRecord, LactationSide, MomBodyDiscomfortSeverity, MomBodyDiscomfortSite, MomBodyEnergy, MomBodyImpact, MomBodyTag, MomBodyTrend, MomBreastComfort, MomComfort, MomDayRestBand, MomEnergy, MomMood, MomMoodFunctionImpact, MomMoodPressure, MomMoodSupport, MomMoodTone, MomRestDisruption, MomResleepDifficulty, MomSleepInterruptions, MomSleepQuality, MomSleepRecovery, MomSleepStretchBand, MomSleepTotalBand, MomStatus, MomSupport, MomUrination, MomBowel, PersonalSchedule } from '../types'
import { AgentRequestError, streamAgentResponse } from '../api/agent'
import {
  AgentVoicePlaybackCoordinator,
  createAgentVoicePlaybackSession,
  type AgentVoicePlaybackSession,
} from '../api/agentVoice'
import {
  AGENT_FILE_ACCEPT,
  AGENT_IMAGE_ACCEPT,
  formatAgentAttachmentSize,
  selectAgentAttachmentCandidates,
  type AgentAttachmentPayload,
  type AgentAttachmentSource,
} from '../api/agentAttachments'
import cozymateAvatar from '../assets/momcozy-agent.png'
// Demo-only portrait placeholders; replace with consented, verified provider photos before production.
import jamieExpertAvatar from '../assets/experts/jamie-lee-avatar.png'
import averyExpertAvatar from '../assets/experts/avery-chen-avatar.png'
import sofiaExpertAvatar from '../assets/experts/sofia-martinez-avatar.png'
import navMe from '../assets/nav_me.svg'
import navBaby from '../assets/nav_baby_pacifier_clear.svg'
import navPlan from '../assets/nav_plan.svg'
import navMore from '../assets/nav_more.svg'
import babyMonitorPreview from '../assets/me_baby_overview/2.0x/nursery_camera_clean.png'

const navItems = [
  { path: '/app/home', label: 'Me', asset: navMe },
  { path: '/app/baby', label: 'Baby', asset: navBaby },
  { path: '/app/agent', label: 'Cozymate' },
  { path: '/app/plan', label: 'Schedule', asset: navPlan },
  { path: '/app/more', label: 'More', asset: navMore }
]

const AGENT_VOICE_PREFERENCE_KEY = 'momcozy-agent-voice-enabled'

function readAgentVoicePreference() {
  if (typeof window === 'undefined') return true
  try {
    const saved = window.localStorage.getItem(AGENT_VOICE_PREFERENCE_KEY)
    return saved === null ? true : saved === 'true'
  } catch {
    return true
  }
}

type ServiceExpertProfile = {
  id: string
  name: string
  credential: string
  focus: string
  languages: string
  bio: string
  avatar: string
}

const serviceExpertProfiles: Record<string, ServiceExpertProfile> = {
  'ibclc-lee': {
    id: 'ibclc-lee',
    name: 'Jamie Lee',
    credential: 'IBCLC',
    focus: '喂养节奏与奶量管理',
    languages: '英语、中文',
    bio: '擅长把喂养中的小变化，整理成可以一步步尝试的方案。',
    avatar: jamieExpertAvatar,
  },
  'ibclc-chen': {
    id: 'ibclc-chen',
    name: 'Avery Chen',
    credential: 'IBCLC',
    focus: '含乳与亲喂调整',
    languages: '英语、中文',
    bio: '关注妈妈和宝宝当下的感受，帮助找到更舒服的喂养方式。',
    avatar: averyExpertAvatar,
  },
  'ibclc-martinez': {
    id: 'ibclc-martinez',
    name: 'Sofia Martinez',
    credential: 'IBCLC',
    focus: '母乳转衔与喂养节奏',
    languages: '英语、中文',
    bio: '擅长在不同喂养方式之间找到适合家庭日常的平衡。',
    avatar: sofiaExpertAvatar,
  },
}

const serviceExpertTeam = Object.values(serviceExpertProfiles)

// Shared overview copy for the automated daily report and the IBCLC follow-up.
const packageDailyFollowupCopy = 'AI每日生成用户状态报告，IBCLC每日跟进反馈'

function serviceExpertProfileFor(expertId?: string, expertName?: string): ServiceExpertProfile {
  if (expertId && serviceExpertProfiles[expertId]) return serviceExpertProfiles[expertId]
  if (expertName?.includes('Avery Chen')) return serviceExpertProfiles['ibclc-chen']
  if (expertName?.includes('Jamie Lee')) return serviceExpertProfiles['ibclc-lee']
  const displayName = expertName?.replace(/,?\s*IBCLC$/i, '').trim()
  return {
    id: expertId ?? 'ibclc-unknown',
    name: displayName || 'IBCLC 专家',
    credential: 'IBCLC',
    focus: '哺乳与喂养支持',
    languages: '以预约页面显示为准',
    bio: '会根据你的情况，在预约时为你匹配合适的专家。',
    avatar: '',
  }
}

function ExpertAvatar({ expertId, expertName, className = '', alt }: { expertId?: string; expertName?: string; className?: string; alt?: string }) {
  const expert = serviceExpertProfileFor(expertId, expertName)
  if (!expert.avatar) {
    const initials = expert.name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase()
    return <span className={`assigned-expert-avatar fallback ${className}`.trim()} aria-label={alt ?? `${expert.name} 头像`}>{initials || 'IB'}</span>
  }
  return <img className={`assigned-expert-avatar ${className}`.trim()} src={expert.avatar} alt={alt ?? `${expert.name} 头像`} loading="lazy" />
}

function AssignedExpertIdentity({ expertId, expertName, label = '本次咨询专家', className = '' }: { expertId?: string; expertName?: string; label?: string; className?: string }) {
  const expert = serviceExpertProfileFor(expertId, expertName)
  return <div className={`assigned-expert-identity ${className}`.trim()}>
    <ExpertAvatar expertId={expertId} expertName={expertName} />
    <div><span>{label}</span><strong>{expert.name}<small>{expert.credential}</small></strong><em>{expert.focus}</em></div>
  </div>
}

function ServiceExpertTeam({ compact = false, onViewTeam }: { compact?: boolean; onViewTeam: () => void }) {
  return <section className={`service-expert-team ${compact ? 'compact' : ''}`} aria-label="IBCLC 专家团队">
    <div className="service-expert-team-avatars" aria-hidden="true">
      {serviceExpertTeam.slice(0, 3).map((expert) => <img key={expert.id} src={expert.avatar} alt="" loading="lazy" />)}
      <span className="service-expert-team-more">…</span>
    </div>
    <div className="service-expert-team-copy"><strong>IBCLC 专家团队服务</strong></div>
    <button type="button" className="service-expert-team-action" onClick={onViewTeam}>了解团队 <Icon name="arrow" /></button>
  </section>
}

function ServiceExpertTeamModal({ onClose }: { onClose: () => void }) {
  return <Modal title="IBCLC 专家团队" className="service-expert-modal" onClose={onClose}>
    <div className="service-expert-modal-intro">服务包不会预先绑定某一位专家。购买后，我们会结合你的问题和可预约时间，提供可选的专家。</div>
    <div className="service-expert-profile-list">
      {serviceExpertTeam.map((expert) => <article key={expert.id} className="service-expert-profile">
        <img src={expert.avatar} alt={`${expert.name} 头像`} loading="lazy" />
        <div><strong>{expert.name}</strong><span>{expert.credential} · {expert.focus}</span><small>{expert.languages}</small><p>{expert.bio}</p></div>
      </article>)}
    </div>
    <div className="service-expert-modal-note"><Icon name="shield" /><span>预约确认前，你会看到并确认本次具体专家。</span></div>
  </Modal>
}

function CozymateNavAvatar({ selected }: { selected: boolean }) {
  return <span className={`nav-agent-avatar ${selected ? 'selected' : ''}`}>
    <span className="nav-agent-wake-halo" aria-hidden="true" />
    <span className="nav-agent-wake-ring" aria-hidden="true" />
    <img className="nav-agent-base" src={cozymateAvatar} alt="" />
  </span>
}

export function AuthPage() {
  const navigate = useNavigate()
  const [step, setStep] = useState<'login' | 'mfa'>('login')
  const [email, setEmail] = useState('mia@example.com')
  const [code, setCode] = useState('')
  const [error, setError] = useState('')
  const submit = () => {
    setError('')
    if (step === 'login') { if (!email.includes('@')) { setError('请输入有效的邮箱地址'); return } setStep('mfa'); return }
    if (code !== '246810') { setError('验证码不正确。演示验证码：246810'); return }
    navigate('/app/home')
  }
  return <div className="auth-viewport"><div className="auth-card"><div className="auth-brand"><span className="brand-mark"><Icon name="spark" /></span><span>momcozy<span>care</span></span></div>{step === 'login' ? <><p className="eyebrow">欢迎回来</p><h1>把今天交给一个<br />可靠的节奏</h1><label className="auth-label">邮箱地址<input aria-label="邮箱地址" value={email} onChange={(event) => setEmail(event.target.value)} type="email" /></label><Button size="lg" onClick={submit}>继续 <Icon name="arrow" /></Button><p className="auth-foot">继续即表示你同意服务条款和隐私政策。</p></> : <><button className="back-button" onClick={() => setStep('login')}>返回修改邮箱</button><p className="eyebrow">安全验证</p><h1>输入一次性验证码</h1><p className="intro-body">验证码已发送至 {email}。</p><label className="auth-label">6 位验证码<input aria-label="验证码" inputMode="numeric" value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, '').slice(0, 6))} placeholder="246810" /></label>{error && <div className="inline-error">{error}</div>}<Button size="lg" onClick={submit} disabled={code.length !== 6}>完成登录 <Icon name="arrow" /></Button><button className="text-button auth-resend">重新发送验证码</button></>} {step === 'login' && error && <div className="inline-error">{error}</div>}<div className="auth-security"><Icon name="shield" /><span>MFA 安全登录</span></div></div></div>
}

function UserShell({ children }: { children: React.ReactNode }) {
  const location = useLocation()
  const isAgentRoute = location.pathname.startsWith('/app/agent') || location.pathname.startsWith('/app/cozymate')
  const active = isAgentRoute ? '/app/agent' : navItems.find((item) => location.pathname.startsWith(item.path))?.path ?? '/app/home'
  const primaryRoutes = new Set([...navItems.map((item) => item.path), '/app/me', '/app/cozymate'])
  const coversPrimaryNav = !primaryRoutes.has(location.pathname)
  return <div className="user-viewport"><div className={`user-shell reference-theme-shell ${coversPrimaryNav ? 'secondary-flow' : ''} ${isAgentRoute ? 'agent-shell' : ''}`}>
    <main className="user-content">{children}</main>
    {!coversPrimaryNav && <nav className="bottom-nav" aria-label="主导航">{navItems.map((item) => {
      const isActive = active === item.path
      const isAgentItem = item.path === '/app/agent'
      const iconStyle = !isAgentItem && 'asset' in item ? { '--nav-icon': `url("${item.asset}")` } as CSSProperties : undefined
      return <Link key={item.path} to={item.path} className={`nav-item ${isAgentItem ? 'agent-nav-item' : ''} ${isActive ? 'active' : ''}`} aria-label={item.label} aria-current={isActive ? 'page' : undefined}>{isAgentItem ? <CozymateNavAvatar selected={isActive} /> : <span className="nav-asset" style={iconStyle} aria-hidden="true" />}<span>{item.label}</span></Link>
    })}</nav>}
  </div></div>
}

function PageIntro({ eyebrow, title, body, back }: { eyebrow?: string; title: string; body?: string; back?: boolean }) {
  const navigate = useNavigate()
  return <div className="page-intro">{back && <button className="back-button" onClick={() => navigate(-1)}>返回</button>}{eyebrow && <p className="eyebrow">{eyebrow}</p>}<h1>{title}</h1>{body && <p className="intro-body">{body}</p>}</div>
}

const comfortLabels: Record<MomComfort, string> = { comfortable: '舒适', okay: '一般', uncomfortable: '不适' }
const sleepQualityLabels: Record<MomSleepQuality, string> = { rested: '恢复得不错', okay: '一般', fragmented: '断断续续' }
const sleepTotalBandLabels: Record<MomSleepTotalBand, string> = { 'under-3h': '<3 小时', '3-4h': '3–4 小时', '4-5h': '4–5 小时', '5-6h': '5–6 小时', '6h-plus': '≥6 小时', unknown: '记不清' }
const sleepInterruptionLabels: Record<MomSleepInterruptions, string> = { none: '没有', '1-2': '1–2 次', '3-4': '3–4 次', '5-plus': '5 次以上', unknown: '记不清' }
const sleepStretchLabels: Record<MomSleepStretchBand, string> = { 'under-1h': '<1 小时', '1-2h': '1–2 小时', '2-3h': '2–3 小时', '3h-plus': '≥3 小时', unknown: '记不清' }
const sleepRecoveryLabels: Record<MomSleepRecovery, string> = { restored: '有恢复', managing: '勉强能撑', exhausted: '很疲惫' }
const dayRestLabels: Record<MomDayRestBand, string> = { none: '没有', 'under-30m': '<30 分钟', '30-60m': '30–60 分钟', '60m-plus': '≥1 小时' }
const resleepLabels: Record<MomResleepDifficulty, string> = { easy: '容易', 'somewhat-hard': '有点难', hard: '很难' }
const restDisruptionLabels: Record<MomRestDisruption, string> = { feeding: '喂奶', baby: '宝宝醒了', discomfort: '身体不适', 'cannot-sleep': '睡不回去', environment: '环境影响', other: '其他' }
const energyLabels: Record<MomEnergy, string> = { energized: '有精神', okay: '一般', tired: '很疲惫' }
const moodLabels: Record<MomMood, string> = { calm: '平静', anxious: '有点焦虑', low: '有点低落', irritable: '容易烦躁', unclear: '说不清楚' }
const supportLabels: Record<MomSupport, string> = { supported: '有人帮我', 'some-help': '偶尔有人帮', alone: '主要靠自己' }
const moodToneLabels: Record<MomMoodTone, string> = { steady: '还算平稳', tense: '有点绷着', low: '低落 / 没力气', reactive: '很容易被触发', unclear: '说不清楚' }
const moodPressureLabels: Record<MomMoodPressure, string> = { 'baby-worry': '担心宝宝', 'feeding-pressure': '喂养压力', 'body-recovery': '身体恢复', 'sleep-loss': '睡不好', 'family-friction': '和家人相处', 'self-doubt': '对自己没信心', 'no-time': '没有自己的时间', unclear: '说不清楚' }
const moodImpactLabels: Record<MomMoodFunctionImpact, string> = { none: '没有影响', some: '有一点影响', hard: '很难完成日常事情' }
const moodSupportLabels: Record<MomMoodSupport, string> = { supported: '有人帮到我', 'carrying-most': '有人，但主要还是我在扛', alone: '基本靠自己' }
const bodyTagLabels: Record<MomBodyTag, string> = { pain: '疼痛', breast: '乳房不适', wound: '伤口/会阴', bleeding: '出血变化', fever: '发热/发冷', urinary: '排尿', bowel: '排便' }
const bodyEnergyLabels: Record<MomBodyEnergy, string> = { energized: '有力气', managing: '勉强应付', depleted: '身体被掏空' }
const discomfortSiteLabels: Record<MomBodyDiscomfortSite, string> = { 'lower-abdomen': '下腹 / 宫缩', perineum: '会阴 / 伤口', 'c-section': '剖腹产切口', back: '腰背', 'head-chest': '头痛 / 胸闷', other: '其他' }
const discomfortSeverityLabels: Record<MomBodyDiscomfortSeverity, string> = { mild: '轻微', noticeable: '明显', 'hard-to-ignore': '很难忽略' }
const bodyImpactLabels: Record<MomBodyImpact, string> = { none: '没有影响', some: '有一点影响', 'care-limited': '影响走路 / 抱宝宝' }
const bodyTrendLabels: Record<MomBodyTrend, string> = { better: '好一些', same: '差不多', worse: '更不舒服' }
const urinationLabels: Record<MomUrination, string> = { normal: '正常', 'leaking-urgency': '尿急 / 漏尿', 'painful-difficult': '刺痛 / 困难' }
const bowelLabels: Record<MomBowel, string> = { smooth: '顺畅', difficult: '费力', 'painful-piles': '疼痛 / 痔疮' }
const breastComfortLabels: Record<MomBreastComfort, string> = { comfortable: '舒服', full: '胀满', painful: '疼痛', uncertain: '说不清楚' }
const lactationMethodLabels: Record<LactationMethod, string> = { pump: '泵奶', nurse: '亲喂' }
const lactationSideLabels: Record<LactationSide, string> = { left: '左侧', right: '右侧' }
const lactationSides: LactationSide[] = ['left', 'right']
const diaryTabs = [
  { id: 'rest', label: '休息' },
  { id: 'body', label: '身体' },
  { id: 'mood', label: '心情' }
] as const
type DiaryTab = typeof diaryTabs[number]['id']
type ActiveDiaryTab = DiaryTab | 'lactation'
const diaryViews: Record<DiaryTab, { title: string; icon: string; description: string }> = {
  rest: { title: '昨夜休息', icon: 'moon', description: '休息的长短和感受，都值得被看见。' },
  body: { title: '身体与精力', icon: 'heart', description: '慢慢感受，今天的身体需要什么。' },
  mood: { title: '今日心情', icon: 'spark', description: '不用急着变好，如实记录此刻的心情。' },
}

function isToday(value?: string) {
  if (!value) return false
  const date = new Date(value)
  const now = new Date()
  return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth() && date.getDate() === now.getDate()
}

function localDateKey(date = new Date()) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function localTimeValue(date = new Date()) {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function todayAtTime(value: string) {
  const [hours, minutes] = value.split(':').map(Number)
  const date = new Date()
  date.setHours(hours, minutes, 0, 0)
  return date
}

function recordPumpVolume(record: LactationRecord) {
  if (record.method !== 'pump') return undefined
  if (record.totalVolumeMl !== undefined) return record.totalVolumeMl
  const values = [record.leftVolumeMl, record.rightVolumeMl].filter((value): value is number => value !== undefined)
  return values.length ? values.reduce((sum, value) => sum + value, 0) : undefined
}

function recordNursingDuration(record: LactationRecord) {
  if (record.method !== 'nurse') return undefined
  if (record.durationMinutes !== undefined) return record.durationMinutes
  const values = [record.leftDurationMinutes, record.rightDurationMinutes].filter((value): value is number => value !== undefined)
  return values.length ? values.reduce((sum, value) => sum + value, 0) : undefined
}

function lactationRecordSideLabel(record: LactationRecord) {
  return record.side === 'right' ? '右侧' : record.side === 'left' ? '左侧' : '历史记录'
}

function editableLactationSide(record?: LactationRecord): LactationSide {
  if (!record) return 'left'
  if (record.side === 'right') return 'right'
  if (record.side === 'left') return 'left'
  if (record.method === 'pump' && record.rightVolumeMl !== undefined && record.leftVolumeMl === undefined) return 'right'
  if (record.method === 'nurse' && record.rightDurationMinutes !== undefined && record.leftDurationMinutes === undefined) return 'right'
  return 'left'
}

function lactationRecordDetail(record: LactationRecord) {
  if (record.method === 'pump') {
    if (record.totalVolumeMl !== undefined) return `${record.totalVolumeMl} ml`
    if (record.side === 'left' && record.leftVolumeMl !== undefined) return `${record.leftVolumeMl} ml`
    if (record.side === 'right' && record.rightVolumeMl !== undefined) return `${record.rightVolumeMl} ml`
    const sides = [record.leftVolumeMl !== undefined ? `左 ${record.leftVolumeMl} ml` : '', record.rightVolumeMl !== undefined ? `右 ${record.rightVolumeMl} ml` : ''].filter(Boolean)
    return sides.length ? sides.join(' · ') : '奶量未记录'
  }
  if (record.durationMinutes !== undefined) return `${record.durationMinutes} 分钟`
  if (record.side === 'left' && record.leftDurationMinutes !== undefined) return `${record.leftDurationMinutes} 分钟`
  if (record.side === 'right' && record.rightDurationMinutes !== undefined) return `${record.rightDurationMinutes} 分钟`
  const sides = [record.leftDurationMinutes !== undefined ? `左 ${record.leftDurationMinutes} 分` : '', record.rightDurationMinutes !== undefined ? `右 ${record.rightDurationMinutes} 分` : ''].filter(Boolean)
  return sides.length ? sides.join(' · ') : '时长未记录'
}

function formatSleep(minutes?: number) {
  if (minutes === undefined) return '未记录'
  const hours = Math.floor(minutes / 60)
  const remainder = minutes % 60
  if (!hours) return `${remainder} 分钟`
  if (!remainder) return `${hours} 小时`
  return `${hours} 小时 ${remainder} 分`
}

function sleepTotalBandFromMinutes(minutes?: number): MomSleepTotalBand | undefined {
  if (minutes === undefined || !Number.isFinite(minutes)) return undefined
  if (minutes < 180) return 'under-3h'
  if (minutes < 240) return '3-4h'
  if (minutes < 300) return '4-5h'
  if (minutes < 360) return '5-6h'
  return '6h-plus'
}

function sleepStretchBandFromMinutes(minutes?: number): MomSleepStretchBand | undefined {
  if (minutes === undefined || !Number.isFinite(minutes)) return undefined
  if (minutes < 60) return 'under-1h'
  if (minutes < 120) return '1-2h'
  if (minutes < 180) return '2-3h'
  return '3h-plus'
}

function recoveryFromLegacyQuality(value?: MomSleepQuality): MomSleepRecovery | undefined {
  if (value === 'rested') return 'restored'
  if (value === 'okay') return 'managing'
  // The old “断断续续” value described fragmentation, not recovery. Do not
  // silently turn it into a subjective fatigue score.
  return undefined
}

function moodToneFromLegacy(value?: MomMood): MomMoodTone | undefined {
  if (value === 'calm') return 'steady'
  if (value === 'anxious') return 'tense'
  if (value === 'low') return 'low'
  if (value === 'irritable') return 'reactive'
  if (value === 'unclear') return 'unclear'
  return undefined
}

function moodSupportFromLegacy(value?: MomSupport): MomMoodSupport | undefined {
  if (value === 'supported') return 'supported'
  if (value === 'some-help') return 'carrying-most'
  if (value === 'alone') return 'alone'
  return undefined
}

function sleepValueFor(status: MomStatus) {
  if (status.sleepTotalBand) return sleepTotalBandLabels[status.sleepTotalBand]
  if (status.sleepMinutes !== undefined) return formatSleep(status.sleepMinutes)
  if (status.sleepRecovery) return sleepRecoveryLabels[status.sleepRecovery]
  if (status.sleepQuality) return sleepQualityLabels[status.sleepQuality]
  return '未记录'
}

type DailyKnowledgeArticle = {
  title: string
  summary: string
  points: string[]
  icon: string
}

type MomKnowledgeTopic = 'body' | 'rest' | 'mood' | 'lactation'

const momKnowledgeArticles: Record<MomKnowledgeTopic, DailyKnowledgeArticle> = {
  body: {
    title: '恢复不是直线，变化本身也值得被看见',
    summary: '体力、不适部位和对日常照护的影响可能每天不同。连续记录这些变化，比要求自己尽快“恢复正常”更能帮你理解身体。',
    points: [
      '先写下今天实际感受到的部位、程度，以及是否影响走路、休息或照护宝宝。',
      '把今天和昨天放在一起看，通常比孤立的一次感受更容易看见恢复过程。',
      '如果不适突然加重、妨碍照顾自己或让你担心，请及时联系医疗专业人员。'
    ],
    icon: 'heart'
  },
  rest: {
    title: '休息不只看时长，也要看身体有没有缓过来',
    summary: '同样的睡眠时长，被打断次数、最长连续休息和醒来后的恢复感不同，身体的负担也可能不同。',
    points: [
      '总时长、被打断次数和最长连续休息，描述的是不同维度，不需要合成一个分数。',
      '醒来后的恢复感能补充数字没有说出的部分，也值得和睡眠时长一起记录。',
      '如果持续疲惫已经影响日常生活，可以把连续记录带给医疗专业人员一起讨论。'
    ],
    icon: 'moon'
  },
  mood: {
    title: '情绪不是成绩，它也在告诉你需要什么',
    summary: '紧绷、低落或容易被触发，并不代表你做得不好。连续记录情绪、压力来源和日常影响，有助于更早看见自己的需要。',
    points: [
      '记录当下最接近的感受即可，不需要把复杂情绪压缩成“好”或“不好”。',
      '压力来自哪里、是否影响睡眠或日常事情，往往比一次情绪标签更有信息。',
      '如果低落或焦虑持续、加重，或已经影响日常生活，请尽早和医疗专业人员沟通。'
    ],
    icon: 'spark'
  },
  lactation: {
    title: '一次泌乳记录，不定义你的身体',
    summary: '单次泵奶量会受到时间、间隔和当时状态影响；连续记录适合用来回看变化，不等于你的总产奶量或喂养能力。',
    points: [
      '按实际发生的时间、方式和侧别记录，不需要用一次结果评价自己。',
      '泵奶量和亲喂时长是不同口径，不能直接相互换算，也不必合成一个数字。',
      '如果持续疼痛或对喂养有担心，可以把连续记录带给医疗或泌乳专业人员。'
    ],
    icon: 'drop'
  }
}

const DAILY_KNOWLEDGE_RELEASE_HOUR = 8

function currentDailyKnowledgeRelease(now = new Date()) {
  const release = new Date(now)
  release.setHours(DAILY_KNOWLEDGE_RELEASE_HOUR, 0, 0, 0)
  if (release.getTime() > now.getTime()) release.setDate(release.getDate() - 1)
  return release
}

function nextDailyKnowledgeRelease(now = new Date()) {
  const release = new Date(now)
  release.setHours(DAILY_KNOWLEDGE_RELEASE_HOUR, 0, 0, 0)
  if (release.getTime() <= now.getTime()) release.setDate(release.getDate() + 1)
  return release
}

function DailyKnowledgeBanner({ label, article, basis, onOpen, splitTitle = false }: { label: string; article: DailyKnowledgeArticle; basis: string; onOpen: () => void; splitTitle?: boolean }) {
  return <button type="button" className="baby-knowledge-banner" onClick={onOpen} aria-label={`Cozymate 为你整理。${basis}。${article.title}。${article.summary} 阅读完整内容`}>
    <span className="baby-knowledge-meta">{label}</span>
    <strong>{splitTitle ? article.title.split('，').map((line, index, lines) => <span className="knowledge-title-line" key={index}>{line}{index < lines.length - 1 ? '，' : ''}</span>) : article.title}</strong>
    <span className="baby-knowledge-preview">{article.summary}</span>
    <span className="baby-knowledge-action" aria-hidden="true"><Icon name="arrow" /></span>
    <span className="baby-knowledge-visual" aria-hidden="true"><img src={cozymateAvatar} alt="" /></span>
  </button>
}

function DailyKnowledgeModal({ title, article, boundary, onClose, onAsk }: { title: string; article: DailyKnowledgeArticle; boundary: string; onClose: () => void; onAsk: () => void }) {
  return <Modal title={title} onClose={onClose} className="baby-knowledge-modal"><article className="baby-knowledge-article">
    <h2>{article.title}</h2>
    <p className="baby-knowledge-summary">{article.summary}</p>
    <div className="baby-knowledge-points">{article.points.map((point, index) => <div key={point}><span>{index + 1}</span><p>{point}</p></div>)}</div>
    <p className="baby-knowledge-boundary"><Icon name="shield" /> {boundary}</p>
    <Button size="lg" className="baby-knowledge-agent-action" onClick={onAsk}><img className="baby-knowledge-agent-icon" src={cozymateAvatar} alt="" />问问 Cozymate <Icon name="arrow" /></Button>
  </article></Modal>
}

function appointmentTimeZone(iso: string, timezone?: string) {
  return timezone && /(?:Z|[+-]\d{2}:\d{2})$/.test(iso) ? timezone : undefined
}

function formatAppointmentDay(iso: string, timezone?: string) {
  return new Intl.DateTimeFormat('zh-CN', {
    month: 'numeric', day: 'numeric', weekday: 'short',
    timeZone: appointmentTimeZone(iso, timezone),
  }).format(new Date(iso))
}

function formatAppointmentClock(iso: string, timezone?: string) {
  return new Intl.DateTimeFormat('zh-CN', {
    hour: '2-digit', minute: '2-digit', hour12: false,
    timeZone: appointmentTimeZone(iso, timezone),
  }).format(new Date(iso))
}

function formatAppointmentRange(start: string, end: string, timezone?: string) {
  return `${formatAppointmentClock(start, timezone)}–${formatAppointmentClock(end, timezone)}`
}

function appointmentDateKey(iso: string, timezone?: string) {
  const formatter = new Intl.DateTimeFormat('en', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    timeZone: appointmentTimeZone(iso, timezone),
  })
  const parts = formatter.formatToParts(new Date(iso))
  const value = (type: Intl.DateTimeFormatPartTypes) => parts.find((part) => part.type === type)?.value ?? ''
  return `${value('year')}-${value('month')}-${value('day')}`
}

function getAppointmentMinutes(start: string, end: string) {
  return Math.round((new Date(end).getTime() - new Date(start).getTime()) / 60000)
}

function DeviceCheckModal({ onClose, onSuccess }: { onClose: () => void; onSuccess?: () => void }) {
  // Start in the pending state so a fast tap cannot launch a second request
  // before the mount-time check begins.
  const [deviceStatus, setDeviceStatus] = useState<'idle' | 'checking' | 'ready' | 'error'>('checking')
  const [deviceError, setDeviceError] = useState('')
  const autoCheckStarted = useRef(false)
  const checkConsultDevices = async () => {
    setDeviceStatus('checking')
    setDeviceError('')
    try {
      if (!navigator.mediaDevices?.getUserMedia) throw new Error('unsupported')
      const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
      let devicesReady = false
      try {
        devicesReady = consultationDevicesReady(stream)
      } finally {
        stream.getTracks().forEach((track) => track.stop())
      }
      if (!devicesReady) throw new Error('missing-device')
      setDeviceStatus('ready')
    } catch {
      setDeviceStatus('error')
      setDeviceError('无法使用摄像头或麦克风，请检查浏览器权限和设备后重试。')
    }
  }
  useEffect(() => {
    if (autoCheckStarted.current) return
    autoCheckStarted.current = true
    void checkConsultDevices()
  }, [])
  const finish = onSuccess ?? onClose
  return <Modal title="检测摄像头与麦克风" className="pre-consult-modal" onClose={onClose}><div className="pre-consult-form">
    <p className="pre-consult-intro">进入咨询室前，请先确认摄像头和麦克风可用。</p>
    <section className={`pre-consult-device ${deviceStatus}`} aria-labelledby="pre-consult-device-title"><span className="pre-consult-device-icon"><Icon name={deviceStatus === 'ready' ? 'check' : 'video'} /></span><div><strong id="pre-consult-device-title">摄像头与麦克风</strong><span>{deviceStatus === 'checking' ? '正在请求设备权限…' : deviceStatus === 'ready' ? '摄像头和麦克风均可用' : deviceStatus === 'error' ? '检查未通过，请重试' : '检查浏览器权限和设备是否可用'}</span></div><Button size="sm" variant={deviceStatus === 'ready' ? 'soft' : 'secondary'} disabled={deviceStatus === 'checking'} onClick={checkConsultDevices}>{deviceStatus === 'checking' ? '检查中…' : deviceStatus === 'ready' ? '重新检查' : '开始检测'}</Button></section>
    {deviceError && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{deviceError}</span></div>}
    {deviceStatus === 'ready' && <Button size="lg" onClick={finish}>{onSuccess ? '继续确认' : '完成'}</Button>}
  </div></Modal>
}

function StartConsultModal({ initialLocation, consentReady, busy, error, onClose, onEnter, onRestoreConsent }: { initialLocation: string; consentReady: boolean; busy: boolean; error?: string; onClose: () => void; onEnter: (stateCode: string) => Promise<boolean>; onRestoreConsent: () => void }) {
  const [consultLocation, setConsultLocation] = useState(initialLocation)
  const consultLocationSupported = consultLocation === 'CA'
  return <Modal title="开始视频咨询" className="pre-consult-modal" onClose={onClose}><div className="pre-consult-form">
    <p className="pre-consult-intro">开始前请确认你当前所在的位置。</p>
    <label className="eligibility-field" htmlFor="consult-location"><span>当前所在州</span><select id="consult-location" value={consultLocation} onChange={(event) => setConsultLocation(event.target.value)}><option value="CA">California (CA)</option><option value="NY">New York (NY)</option><option value="TX">Texas (TX)</option></select></label>
    {!consultLocationSupported && <div className="inline-warning" role="alert"><Icon name="shield" /><span>当前 IBCLC 仅支持位于 California 的用户进行视频咨询。</span></div>}
    {!consentReady && <div className="inline-warning"><Icon name="lock" /><span>视频授权已撤回</span><button className="text-button" onClick={onRestoreConsent}>去授权</button></div>}
    {error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{error}</span></div>}
    <Button size="lg" disabled={!consultLocationSupported || !consentReady || busy} onClick={() => { void onEnter(consultLocation) }}>{busy ? '正在进入…' : '确认并进入咨询室'}</Button>
  </div></Modal>
}

function HomeConsultPreparation({ appointment, onCancel, onStart }: { appointment: Appointment; onCancel: () => void; onStart: () => void }) {
  const { consultation } = useProduct()
  const demoMode = isConsultationDemo(consultation.mode, import.meta.env.VITE_CONSULTATION_DEV_AUTH)
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(timer)
  }, [])
  const startAt = new Date(appointment.start).getTime()
  const endAt = new Date(appointment.end).getTime()
  const remaining = startAt - now
  const isStartWindow = remaining <= 10 * 60 * 1000 && now < endAt
  const isLiveWindow = remaining <= 0 && now < endAt
  const isPast = now >= endAt
  const canEnter = canEnterConsultationByTime(appointment, now, demoMode)
  const demoEntry = demoMode && canEnter
  const countdownValue = demoEntry ? '可随时进入' : consultationCountdown(appointment, now)
  const countdownLabel = demoEntry ? '演示模式' : isPast ? '咨询状态' : isLiveWindow ? '咨询已开始' : '距离咨询'
  const progress = remaining <= 0 ? 1 : Math.max(0, Math.min(1, 1 - remaining / (24 * 60 * 60 * 1000)))
  return <section className="home-consult-preparation" aria-label="预约与咨询准备">
    <div className="home-consult-appointment">
      <span><small>{appointment.consultationSequenceLabel ?? '首次咨询'}</small><strong>{formatAppointmentDay(appointment.start, appointment.timezone)} · {formatAppointmentRange(appointment.start, appointment.end, appointment.timezone)}</strong><small>{appointment.ibclcName}</small></span>
    </div>
    <div className={`consult-countdown ${canEnter ? 'ready' : ''} ${isPast && !demoEntry ? 'past' : ''}`} aria-label={`${countdownLabel} ${countdownValue}`}>
      <span className="consult-countdown-ring" style={{ '--countdown-progress': `${progress * 360}deg` } as CSSProperties}><Icon name="clock" /></span>
      <span><small>{countdownLabel}</small><strong>{countdownValue}</strong></span>
    </div>
    <p>开始前请确认当前所在州为 California，并确保摄像头与麦克风可用。</p>
    <div className="home-consult-actions"><Button size="sm" variant="danger" onClick={onCancel}>取消预约</Button><Button size="sm" disabled={!canEnter} onClick={onStart}>{isLiveWindow ? '进入咨询' : '开始咨询'}</Button></div>
    {demoMode ? <small className="consult-start-note">演示模式不受预约时间限制，可直接开始咨询</small> : !isStartWindow && !isPast && <small className="consult-start-note">咨询开始前 10 分钟可进入</small>}
  </section>
}

function HomePage() {
  const { state, dispatch, consultation } = useProduct()
  const navigate = useNavigate()
  const [momKnowledgeOpen, setMomKnowledgeOpen] = useState(false)
  const [momKnowledgeReleasedAt, setMomKnowledgeReleasedAt] = useState(currentDailyKnowledgeRelease)
  const [statusEditorOpen, setStatusEditorOpen] = useState(false)
  const [statusRecordChoiceOpen, setStatusRecordChoiceOpen] = useState(false)
  const [appointmentDetailEpisodeId, setAppointmentDetailEpisodeId] = useState<string>()
  const [lactationModalOpen, setLactationModalOpen] = useState(false)
  const [deviceCheckPackageId, setDeviceCheckPackageId] = useState<string>()
  const [startConsultPackageId, setStartConsultPackageId] = useState<string>()
  const [cancelAppointmentTarget, setCancelAppointmentTarget] = useState<Appointment>()
  const [activeDiaryTab, setActiveDiaryTab] = useState<ActiveDiaryTab>('rest')
  const [statusError, setStatusError] = useState('')
  const [lactationFormOpen, setLactationFormOpen] = useState(false)
  const [lactationDraftId, setLactationDraftId] = useState('')
  const [editingLactationId, setEditingLactationId] = useState<string>()
  const [lactationMethod, setLactationMethod] = useState<LactationMethod>('pump')
  const [lactationTime, setLactationTime] = useState(localTimeValue())
  const [lactationSide, setLactationSide] = useState<LactationSide>('left')
  const [leftVolumeMl, setLeftVolumeMl] = useState('')
  const [rightVolumeMl, setRightVolumeMl] = useState('')
  const [leftDurationMinutes, setLeftDurationMinutes] = useState('')
  const [rightDurationMinutes, setRightDurationMinutes] = useState('')
  const [lactationFeeling, setLactationFeeling] = useState<MomBreastComfort | ''>('')
  const [lactationNote, setLactationNote] = useState('')
  const [lactationError, setLactationError] = useState('')
  const [lactationMessage, setLactationMessage] = useState('')
  const [deletedLactationRecord, setDeletedLactationRecord] = useState<LactationRecord>()
  const [comfort, setComfort] = useState<MomComfort | ''>('')
  const [bodyTags, setBodyTags] = useState<MomBodyTag[]>([])
  const [painScore, setPainScore] = useState('')
  const [bodyNote, setBodyNote] = useState('')
  const [bodyEnergy, setBodyEnergy] = useState<MomBodyEnergy | ''>('')
  const [discomfortSites, setDiscomfortSites] = useState<MomBodyDiscomfortSite[]>([])
  const [discomfortSeverity, setDiscomfortSeverity] = useState<MomBodyDiscomfortSeverity | ''>('')
  const [bodyImpact, setBodyImpact] = useState<MomBodyImpact | ''>('')
  const [recoveryTrend, setRecoveryTrend] = useState<MomBodyTrend | ''>('')
  const [urination, setUrination] = useState<MomUrination | ''>('')
  const [bowel, setBowel] = useState<MomBowel | ''>('')
  const [moodTone, setMoodTone] = useState<MomMoodTone | ''>('')
  const [moodPressures, setMoodPressures] = useState<MomMoodPressure[]>([])
  const [moodFunctionImpact, setMoodFunctionImpact] = useState<MomMoodFunctionImpact | ''>('')
  const [moodSupport, setMoodSupport] = useState<MomMoodSupport | ''>('')
  const [sleepTotalBand, setSleepTotalBand] = useState<MomSleepTotalBand | ''>('')
  const [sleepInterruptions, setSleepInterruptions] = useState<MomSleepInterruptions | ''>('')
  const [sleepStretchBand, setSleepStretchBand] = useState<MomSleepStretchBand | ''>('')
  const [sleepRecovery, setSleepRecovery] = useState<MomSleepRecovery | ''>('')
  const [dayRestBand, setDayRestBand] = useState<MomDayRestBand | ''>('')
  const [resleepDifficulty, setResleepDifficulty] = useState<MomResleepDifficulty | ''>('')
  const [restDisruptions, setRestDisruptions] = useState<MomRestDisruption[]>([])
  const [energy, setEnergy] = useState<MomEnergy | ''>('')
  const [mood, setMood] = useState<MomMood | ''>('')
  const [support, setSupport] = useState<MomSupport | ''>('')
  useEffect(() => {
    const nextRelease = nextDailyKnowledgeRelease()
    const timer = window.setTimeout(() => setMomKnowledgeReleasedAt(currentDailyKnowledgeRelease()), Math.max(1000, nextRelease.getTime() - Date.now()))
    return () => window.clearTimeout(timer)
  }, [momKnowledgeReleasedAt])
  useEffect(() => {
    if (!statusEditorOpen && !lactationModalOpen && !momKnowledgeOpen && !statusRecordChoiceOpen && !appointmentDetailEpisodeId) return
    const dialog = document.querySelector<HTMLElement>('.me-page > [role="dialog"]')
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : undefined
    const focusable = () => Array.from(dialog?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), textarea:not(:disabled), select:not(:disabled), a[href], summary, [tabindex="0"]') ?? []).filter((element) => element.getClientRects().length > 0)
    focusable()[0]?.focus({ preventScroll: true })
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Tab') {
        const elements = focusable()
        const first = elements[0]
        const last = elements.at(-1)
        if (first && (!dialog?.contains(document.activeElement) || (event.shiftKey ? document.activeElement === first : document.activeElement === last))) {
          event.preventDefault()
          ;(event.shiftKey ? last : first)?.focus()
        }
      }
      if (event.key !== 'Escape') return
      setStatusEditorOpen(false)
      setLactationModalOpen(false)
      setMomKnowledgeOpen(false)
      setStatusRecordChoiceOpen(false)
      setAppointmentDetailEpisodeId(undefined)
    }
    window.addEventListener('keydown', closeOnEscape)
    return () => { window.removeEventListener('keydown', closeOnEscape); if (opener?.isConnected) opener.focus({ preventScroll: true }) }
  }, [statusEditorOpen, lactationModalOpen, momKnowledgeOpen, statusRecordChoiceOpen, appointmentDetailEpisodeId])
  const nextTask = state.carePlan?.tasks.find((task) => !['completed', 'skipped', 'expired'].includes(task.status))
  const storedToday = state.momDiary?.find((entry) => entry.dateKey === localDateKey())
  const momStatus = storedToday ?? (isToday(state.momStatus?.updatedAt) ? state.momStatus : { lactation: {} })
  const legacyLactation = momStatus.lactation
  const legacyLactationRecordedToday = isToday(legacyLactation.loggedAt) && (legacyLactation.amountMl !== undefined || legacyLactation.sessions !== undefined)
  const todayLactationRecords = useMemo(() => state.lactationRecords
    .filter((record) => localDateKey(new Date(record.occurredAt)) === localDateKey())
    .sort((a, b) => new Date(b.occurredAt).getTime() - new Date(a.occurredAt).getTime()), [state.lactationRecords])
  const pumpRecords = todayLactationRecords.filter((record) => record.method === 'pump')
  const nursingRecords = todayLactationRecords.filter((record) => record.method === 'nurse')
  const measuredPumpVolumes = pumpRecords.map(recordPumpVolume).filter((value): value is number => value !== undefined)
  const measuredNursingDurations = nursingRecords.map(recordNursingDuration).filter((value): value is number => value !== undefined)
  const totalPumpVolume = measuredPumpVolumes.length
    ? measuredPumpVolumes.reduce((sum, value) => sum + value, 0)
    : pumpRecords.length ? undefined : legacyLactation.amountMl
  const pumpCount = pumpRecords.length || legacyLactation.sessions || 0
  const nursingDuration = measuredNursingDurations.length ? measuredNursingDurations.reduce((sum, value) => sum + value, 0) : undefined
  const lactationRecordedToday = todayLactationRecords.length > 0 || legacyLactationRecordedToday
  const statusUpdatedToday = isToday(momStatus.updatedAt)
  const lactationValue = totalPumpVolume !== undefined
    ? `${totalPumpVolume} ml`
    : nursingDuration !== undefined ? `${nursingDuration} 分钟` : lactationRecordedToday ? `${pumpCount + nursingRecords.length} 次` : '未记录'
  const lactationHomeMeta = lactationRecordedToday
    ? [`泵奶 ${pumpCount} 次`, `亲喂 ${nursingRecords.length} 次`].filter((item) => !item.includes(' 0 ')).join(' · ') || '已记录'
    : '按次保存，随时可补充'
  const pumpSummary = pumpCount ? `${totalPumpVolume !== undefined ? `${totalPumpVolume} ml · ` : ''}${pumpCount} 次` : '未记录'
  const nursingSummary = nursingRecords.length ? `${nursingRecords.length} 次${nursingDuration !== undefined ? ` · ${nursingDuration} 分` : ''}` : '未记录'
  const latestLactationTime = todayLactationRecords[0] ? new Date(todayLactationRecords[0].occurredAt).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' }) : undefined
  const bodyValue = statusUpdatedToday && (momStatus.bodyEnergy || momStatus.energy || momStatus.comfort)
    ? momStatus.bodyEnergy ? bodyEnergyLabels[momStatus.bodyEnergy] : momStatus.comfort === 'uncomfortable' ? comfortLabels.uncomfortable : momStatus.energy ? energyLabels[momStatus.energy] : comfortLabels[momStatus.comfort as MomComfort]
    : '未记录'
  const sleepValue = statusUpdatedToday ? sleepValueFor(momStatus) : '未记录'
  const moodValue = statusUpdatedToday && (momStatus.moodTone || momStatus.mood)
    ? momStatus.moodTone ? moodToneLabels[momStatus.moodTone] : moodLabels[momStatus.mood as MomMood]
    : '未记录'
  const diaryCompletion: Record<DiaryTab, boolean> = {
    rest: Boolean(statusUpdatedToday && (momStatus.sleepTotalBand || momStatus.sleepInterruptions || momStatus.sleepStretchBand || momStatus.sleepRecovery || momStatus.dayRestBand || momStatus.resleepDifficulty || momStatus.restDisruptions?.length || momStatus.sleepMinutes !== undefined || momStatus.longestSleepMinutes !== undefined || momStatus.sleepQuality)),
    body: Boolean(statusUpdatedToday && (momStatus.bodyEnergy || momStatus.comfort || momStatus.bodyTags?.length || momStatus.bodyNote || momStatus.discomfortSites?.length || momStatus.recoveryTrend || momStatus.urination || momStatus.bowel)),
    mood: Boolean(statusUpdatedToday && (momStatus.moodTone || momStatus.moodPressures?.length || momStatus.moodFunctionImpact || momStatus.moodSupport || momStatus.energy || momStatus.mood || momStatus.support))
  }
  const completedDiaryTabs = diaryTabs.filter((tab) => diaryCompletion[tab.id]).length
  const diaryView = diaryViews[activeDiaryTab === 'lactation' ? 'rest' : activeDiaryTab]
  const momKnowledgeWindowEnd = momKnowledgeReleasedAt.getTime()
  const momKnowledgeWindowStart = momKnowledgeWindowEnd - 24 * 60 * 60 * 1000
  const inMomKnowledgeWindow = (value?: string) => {
    if (!value) return false
    const timestamp = new Date(value).getTime()
    return timestamp > momKnowledgeWindowStart && timestamp <= momKnowledgeWindowEnd
  }
  const momKnowledgeSignals: Array<{ topic: MomKnowledgeTopic; timestamp: number; relevance: number }> = []
  const momKnowledgeStatuses: MomStatus[] = [...(state.momDiary ?? [])]
  if (!momKnowledgeStatuses.some((entry) => entry.updatedAt === state.momStatus.updatedAt)) momKnowledgeStatuses.push(state.momStatus)
  momKnowledgeStatuses.forEach((entry) => {
    if (!inMomKnowledgeWindow(entry.updatedAt)) return
    const timestamp = new Date(entry.updatedAt as string).getTime()
    const hasBody = Boolean(entry.bodyEnergy || entry.comfort || entry.bodyTags?.length || entry.bodyNote || entry.discomfortSites?.length || entry.discomfortSeverity || entry.bodyImpact || entry.recoveryTrend || entry.urination || entry.bowel || entry.painScore !== undefined)
    const hasRest = Boolean(entry.sleepTotalBand || entry.sleepInterruptions || entry.sleepStretchBand || entry.sleepRecovery || entry.dayRestBand || entry.resleepDifficulty || entry.restDisruptions?.length || entry.sleepMinutes !== undefined || entry.longestSleepMinutes !== undefined || entry.sleepQuality)
    const hasMood = Boolean(entry.moodTone || entry.moodPressures?.length || entry.moodFunctionImpact || entry.moodSupport || entry.energy || entry.mood || entry.support)
    if (hasBody) momKnowledgeSignals.push({ topic: 'body', timestamp, relevance: entry.bodyImpact === 'care-limited' || entry.recoveryTrend === 'worse' || entry.discomfortSeverity === 'hard-to-ignore' ? 4 : 2 })
    if (hasRest) momKnowledgeSignals.push({ topic: 'rest', timestamp, relevance: entry.sleepRecovery === 'exhausted' || entry.sleepTotalBand === 'under-3h' || entry.resleepDifficulty === 'hard' ? 4 : 1 })
    if (hasMood) momKnowledgeSignals.push({ topic: 'mood', timestamp, relevance: entry.moodFunctionImpact === 'hard' || entry.moodTone === 'low' || entry.moodTone === 'reactive' ? 4 : 1 })
  })
  state.lactationRecords.filter((record) => inMomKnowledgeWindow(record.occurredAt)).forEach((record) => {
    momKnowledgeSignals.push({ topic: 'lactation', timestamp: new Date(record.occurredAt).getTime(), relevance: record.feeling === 'painful' ? 4 : 1 })
  })
  const latestMomKnowledgeSignal = momKnowledgeSignals.sort((a, b) => b.timestamp - a.timestamp || b.relevance - a.relevance)[0]
  const fallbackMomKnowledgeTopics: MomKnowledgeTopic[] = ['body', 'rest', 'mood']
  const fallbackMomKnowledgeSeed = [...`${state.user.id}-${localDateKey(momKnowledgeReleasedAt)}`].reduce((total, character) => total + character.charCodeAt(0), 0)
  const momKnowledgeTopic = latestMomKnowledgeSignal?.topic ?? fallbackMomKnowledgeTopics[fallbackMomKnowledgeSeed % fallbackMomKnowledgeTopics.length]
  const dailyMomKnowledge = momKnowledgeArticles[momKnowledgeTopic]
  const momKnowledgeBasis = latestMomKnowledgeSignal
    ? momKnowledgeTopic === 'body' ? '根据最近一天的身体记录'
      : momKnowledgeTopic === 'rest' ? '根据最近一天的休息记录'
        : momKnowledgeTopic === 'mood' ? '根据最近一天的心情记录'
          : '根据最近一天的泌乳记录'
    : `结合${formatPostpartumDay(state.user.postpartumDay)}`
  const beginLactationRecord = (record?: LactationRecord) => {
    const method = record?.method ?? todayLactationRecords[0]?.method ?? 'pump'
    const side = editableLactationSide(record)
    setLactationDraftId(record?.id ?? `lactation-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`)
    setEditingLactationId(record?.id)
    setLactationMethod(method)
    setLactationTime(record ? localTimeValue(new Date(record.occurredAt)) : localTimeValue())
    setLactationSide(side)
    setLeftVolumeMl(record?.leftVolumeMl?.toString() ?? (record?.side === 'left' && record.totalVolumeMl !== undefined ? record.totalVolumeMl.toString() : ''))
    setRightVolumeMl(record?.rightVolumeMl?.toString() ?? (record?.side === 'right' && record.totalVolumeMl !== undefined ? record.totalVolumeMl.toString() : ''))
    setLeftDurationMinutes(record?.leftDurationMinutes?.toString() ?? (record?.side === 'left' && record.durationMinutes !== undefined ? record.durationMinutes.toString() : ''))
    setRightDurationMinutes(record?.rightDurationMinutes?.toString() ?? (record?.side === 'right' && record.durationMinutes !== undefined ? record.durationMinutes.toString() : ''))
    setLactationFeeling(record?.feeling ?? '')
    setLactationNote(record?.note ?? '')
    setLactationError('')
    setLactationMessage('')
    setDeletedLactationRecord(undefined)
    setLactationFormOpen(true)
  }
  const openLactationModal = (startForm = false) => {
    setActiveDiaryTab('lactation')
    setLactationModalOpen(true)
    setLactationMessage('')
    setLactationError('')
    setDeletedLactationRecord(undefined)
    setEditingLactationId(undefined)
    if (startForm) beginLactationRecord()
    else setLactationFormOpen(false)
  }
  const openStatusEditor = (tab: DiaryTab = 'rest') => {
    setActiveDiaryTab(tab)
    setComfort(statusUpdatedToday ? momStatus.comfort ?? '' : '')
    setBodyTags(statusUpdatedToday ? momStatus.bodyTags ?? [] : [])
    setPainScore(statusUpdatedToday && momStatus.painScore !== undefined ? momStatus.painScore.toString() : '')
    setBodyNote(statusUpdatedToday ? momStatus.bodyNote ?? '' : '')
    setBodyEnergy(statusUpdatedToday ? momStatus.bodyEnergy ?? '' : '')
    setDiscomfortSites(statusUpdatedToday ? momStatus.discomfortSites ?? [] : [])
    setDiscomfortSeverity(statusUpdatedToday ? momStatus.discomfortSeverity ?? '' : '')
    setBodyImpact(statusUpdatedToday ? momStatus.bodyImpact ?? '' : '')
    setRecoveryTrend(statusUpdatedToday ? momStatus.recoveryTrend ?? '' : '')
    setUrination(statusUpdatedToday ? momStatus.urination ?? '' : '')
    setBowel(statusUpdatedToday ? momStatus.bowel ?? '' : '')
    setMoodTone(statusUpdatedToday ? momStatus.moodTone ?? moodToneFromLegacy(momStatus.mood) ?? '' : '')
    setMoodPressures(statusUpdatedToday ? momStatus.moodPressures ?? [] : [])
    setMoodFunctionImpact(statusUpdatedToday ? momStatus.moodFunctionImpact ?? '' : '')
    setMoodSupport(statusUpdatedToday ? momStatus.moodSupport ?? moodSupportFromLegacy(momStatus.support) ?? '' : '')
    setSleepTotalBand(statusUpdatedToday ? momStatus.sleepTotalBand ?? sleepTotalBandFromMinutes(momStatus.sleepMinutes) ?? '' : '')
    setSleepInterruptions(statusUpdatedToday ? momStatus.sleepInterruptions ?? '' : '')
    setSleepStretchBand(statusUpdatedToday ? momStatus.sleepStretchBand ?? sleepStretchBandFromMinutes(momStatus.longestSleepMinutes) ?? '' : '')
    setSleepRecovery(statusUpdatedToday ? momStatus.sleepRecovery ?? recoveryFromLegacyQuality(momStatus.sleepQuality) ?? '' : '')
    setDayRestBand(statusUpdatedToday ? momStatus.dayRestBand ?? '' : '')
    setResleepDifficulty(statusUpdatedToday ? momStatus.resleepDifficulty ?? '' : '')
    setRestDisruptions(statusUpdatedToday ? momStatus.restDisruptions ?? [] : [])
    setEnergy(statusUpdatedToday ? momStatus.energy ?? '' : '')
    setMood(statusUpdatedToday ? momStatus.mood ?? '' : '')
    setSupport(statusUpdatedToday ? momStatus.support ?? '' : '')
    setStatusError('')
    setStatusEditorOpen(true)
  }
  const changeLactationMethod = (method: LactationMethod) => {
    if (method === lactationMethod) return
    setLactationMethod(method)
    setLactationSide('left')
    setLeftVolumeMl('')
    setRightVolumeMl('')
    setLeftDurationMinutes('')
    setRightDurationMinutes('')
    setLactationError('')
  }
  const saveLactationRecord = () => {
    const parse = (value: string) => value.trim() ? Number(value) : undefined
    const leftVolume = parse(leftVolumeMl)
    const rightVolume = parse(rightVolumeMl)
    const leftDuration = parse(leftDurationMinutes)
    const rightDuration = parse(rightDurationMinutes)
    const occurredAt = todayAtTime(lactationTime)
    const volume = lactationSide === 'left' ? leftVolume : rightVolume
    const duration = lactationSide === 'left' ? leftDuration : rightDuration
    const volumeValues = lactationMethod === 'pump' && volume !== undefined ? [volume] : []
    const durationValues = lactationMethod === 'nurse' && duration !== undefined ? [duration] : []
    if (!lactationTime || Number.isNaN(occurredAt.getTime())) {
      setLactationError('请选择这次记录发生的时间。')
      return
    }
    if (occurredAt.getTime() > Date.now() + 5 * 60 * 1000) {
      setLactationError('记录时间不能晚于现在。')
      return
    }
    if (volumeValues.some((value) => !Number.isFinite(value) || value < 0 || value > 2000)) {
      setLactationError('请检查奶量，每个输入应在 0–2000 ml 之间。')
      return
    }
    if (durationValues.some((value) => !Number.isInteger(value) || value < 0 || value > 240)) {
      setLactationError('请检查亲喂时长，每个输入应为 0–240 分钟的整数。')
      return
    }
    const now = new Date().toISOString()
    const existing = editingLactationId ? state.lactationRecords.find((record) => record.id === editingLactationId) : undefined
    const record: LactationRecord = {
      id: lactationDraftId || `lactation-${Date.now()}`,
      method: lactationMethod,
      occurredAt: occurredAt.toISOString(),
      side: lactationSide,
      detailMode: 'total',
      ...(lactationMethod === 'pump' && lactationSide === 'left' ? { leftVolumeMl: leftVolume } : {}),
      ...(lactationMethod === 'pump' && lactationSide === 'right' ? { rightVolumeMl: rightVolume } : {}),
      ...(lactationMethod === 'nurse' && lactationSide === 'left' ? { leftDurationMinutes: leftDuration } : {}),
      ...(lactationMethod === 'nurse' && lactationSide === 'right' ? { rightDurationMinutes: rightDuration } : {}),
      feeling: lactationFeeling || undefined,
      note: lactationNote.trim() || undefined,
      source: 'manual',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now
    }
    dispatch({ type: 'upsertLactationRecord', record })
    setLactationFormOpen(false)
    setEditingLactationId(undefined)
    setLactationError('')
    setLactationMessage(existing ? '这次记录已更新。' : '这次记录已保存。')
  }
  const removeLactationRecord = (record: LactationRecord) => {
    dispatch({ type: 'removeLactationRecord', id: record.id })
    setDeletedLactationRecord(record)
    setLactationMessage('')
    if (editingLactationId === record.id) {
      setEditingLactationId(undefined)
      setLactationFormOpen(false)
    }
  }
  const undoRemoveLactationRecord = () => {
    if (!deletedLactationRecord) return
    dispatch({ type: 'upsertLactationRecord', record: deletedLactationRecord })
    setDeletedLactationRecord(undefined)
    setLactationMessage('记录已恢复。')
  }
  const exitLactationForm = () => {
    setLactationError('')
    if (lactationRecordedToday) setLactationFormOpen(false)
    else setLactationModalOpen(false)
  }
  const saveMomStatus = () => {
    const pain = painScore.trim() ? Number(painScore) : undefined
    const hasAnyValue = Boolean(comfort || bodyTags.length || painScore.trim() || bodyNote.trim() || bodyEnergy || discomfortSites.length || discomfortSeverity || bodyImpact || recoveryTrend || urination || bowel || moodTone || moodPressures.length || moodFunctionImpact || moodSupport || sleepTotalBand || sleepInterruptions || sleepStretchBand || sleepRecovery || dayRestBand || resleepDifficulty || restDisruptions.length || energy || mood || support)
    if (!hasAnyValue) {
      setStatusError('先记录一项今天的状态，再保存。')
      return
    }
    if (pain !== undefined && (!Number.isInteger(pain) || pain < 0 || pain > 10)) {
      setStatusError('请检查疼痛程度，应为 0–10 的整数。')
      return
    }
    dispatch({ type: 'setMomStatus', status: {
      /* “整体” tab is no longer part of the current UI. Keep legacy values
         intact when another diary tab is saved so old snapshots are not lost. */
      overall: statusUpdatedToday ? momStatus.overall : undefined,
      lactation: { ...legacyLactation },
      comfort: comfort || undefined,
      bodyTags: bodyTags.length ? bodyTags : undefined,
      painScore: pain,
      bodyNote: bodyNote.trim() || undefined,
      bodyEnergy: bodyEnergy || undefined,
      discomfortSites: discomfortSites.length ? discomfortSites : undefined,
      discomfortSeverity: discomfortSeverity || undefined,
      bodyImpact: bodyImpact || undefined,
      recoveryTrend: recoveryTrend || undefined,
      urination: urination || undefined,
      bowel: bowel || undefined,
      moodTone: moodTone || undefined,
      moodPressures: moodPressures.length ? moodPressures : undefined,
      moodFunctionImpact: moodFunctionImpact || undefined,
      moodSupport: moodSupport || undefined,
      /* These fields are no longer collected in the current mood UI. Keep
         same-day legacy values intact when another signal is saved. */
      moodReliefSources: statusUpdatedToday ? momStatus.moodReliefSources : undefined,
      moodSafety: statusUpdatedToday ? momStatus.moodSafety : undefined,
      moodNote: statusUpdatedToday ? momStatus.moodNote : undefined,
      sleepTotalBand: sleepTotalBand || undefined,
      sleepInterruptions: sleepInterruptions || undefined,
      sleepStretchBand: sleepStretchBand || undefined,
      sleepRecovery: sleepRecovery || undefined,
      dayRestBand: dayRestBand || undefined,
      resleepDifficulty: resleepDifficulty || undefined,
      restDisruptions: restDisruptions.length ? restDisruptions : undefined,
      energy: energy || undefined,
      mood: mood || undefined,
      support: support || undefined,
      dailyNote: statusUpdatedToday ? momStatus.dailyNote : undefined
    } })
    setStatusEditorOpen(false)
  }
  const serviceEntries = state.episodes.flatMap((episode) => {
    const order = state.orders.find((item) => item.id === episode.orderId && item.status === 'paid')
    const packageItem = state.packages.find((item) => item.id === order?.packageId)
    if (!order || !packageItem) return []
    const appointment = preferredAppointmentForEpisode(state.appointments, episode.id)
    const remainingSessions = Math.max(0, episode.remainingSessions)
    const canBookConsultation = remainingSessions > 0
    const progressPath = `/app/care-episodes/${episode.id}/progress`
    const appointmentAction = appointment?.attendanceOutcome && canBookConsultation
      ? { label: '预约咨询', path: '/app/appointment' }
      : appointment?.status === 'in_progress'
      ? { label: '进入咨询', path: `/app/appointments/${appointment.id}?start=1` }
      : appointment?.status === 'confirmed' && !episode.intakeSubmitted
      ? { label: '填写信息', path: '/app/intake' }
      : appointment?.status === 'confirmed'
        ? { label: '开始咨询', path: `/app/appointments/${appointment.id}?start=1` }
      : canBookConsultation
        ? { label: '预约咨询', path: '/app/appointment' }
        : { label: '咨询权益已用完' }
    return [{ episode, packageItem, appointment, appointmentAction, progressPath, remainingSessions, canBookConsultation }]
  })
  const activateService = (packageId: string, path: string, episodeId: string) => {
    dispatch({ type: 'activateService', packageId, episodeId })
    navigate(path)
  }
  const openStartConsult = (packageId: string, appointmentId?: string) => {
    dispatch({ type: 'activateService', packageId })
    if (appointmentId) dispatch({ type: 'activateAppointment', appointmentId })
    consultation.clearError()
    setDeviceCheckPackageId(packageId)
  }
  const requestCancelAppointment = (packageId: string, appointment: Appointment) => {
    dispatch({ type: 'activateService', packageId })
    dispatch({ type: 'activateAppointment', appointmentId: appointment.id })
    consultation.clearError()
    setCancelAppointmentTarget(appointment)
  }
  const cancelHomeAppointment = async () => {
    if (!cancelAppointmentTarget) return
    const cancelled = await consultation.cancel(cancelAppointmentTarget.id)
    if (!cancelled) return
    setCancelAppointmentTarget(undefined)
  }
  const appointmentDetail = serviceEntries.find((entry) => entry.episode.id === appointmentDetailEpisodeId)
  return <div className="page-stack home-page me-page">
    <div className="greeting-row"><div><h1>早上好，{state.user.name.split(' ')[0]}</h1></div><span className="home-day-count">{formatPostpartumDay(state.user.postpartumDay)}</span></div>

    <DailyKnowledgeBanner
      label="更好地了解自己的身体"
      article={dailyMomKnowledge}
      basis={momKnowledgeBasis}
      onOpen={() => setMomKnowledgeOpen(true)}
      splitTitle
    />

    <section className="my-status-section" aria-labelledby="my-status-title">
      <div className="my-status-heading"><h2 id="my-status-title"><MeSectionIcon /><span>我的状态</span></h2><button type="button" className="text-button my-status-record" onClick={() => setStatusRecordChoiceOpen(true)}>记录</button></div>
      <div className="my-status-grid">
        <MeStatusCard kind="rest" label="昨夜休息" value={sleepValue} onClick={() => openStatusEditor('rest')} />
        <MeStatusCard kind="comfort" label="身体与精力" value={bodyValue} onClick={() => openStatusEditor('body')} />
        <MeStatusCard kind="mood" label="今日心情" value={moodValue} onClick={() => openStatusEditor('mood')} />
        <MeStatusCard kind="lactation" label="今日泌乳" value={lactationRecordedToday ? lactationValue : '未记录'} detail={lactationHomeMeta} onClick={() => openLactationModal(false)} />
      </div>
    </section>
    <section className="home-service-section expert-support-updated" aria-labelledby="home-service-title">
      <div className="home-section-heading"><h2 id="home-service-title"><MeSectionIcon support />专家支持</h2>{serviceEntries.length > 0 && <button className="text-button" aria-label="选择其他专家服务包" onClick={() => navigate('/app/services')}>其他服务包 <Icon name="arrow" /></button>}</div>
      {serviceEntries.length > 0 ? <div className="home-service-list" aria-label={`我的专家支持，共 ${serviceEntries.length} 个服务包`}>
        {serviceEntries.map(({ episode, packageItem, appointment, appointmentAction, progressPath, remainingSessions, canBookConsultation }) => {
          const confirmedAppointment = appointment && (appointment.status === 'confirmed' || appointment.status === 'in_progress') ? appointment : undefined
          const showsConsultPreparation = appointment?.status === 'confirmed' && episode.intakeSubmitted
          const expert = confirmedAppointment ? serviceExpertProfileFor(confirmedAppointment.ibclcId, confirmedAppointment.ibclcName) : undefined
          return <MeExpertServiceCard key={episode.id} name={packageItem.name} status={episode.status} durationDays={packageItem.durationDays} remainingSessions={remainingSessions}
            identity={<div className="expert-identity">{expert ? <><ExpertAvatar expertId={expert.id} expertName={expert.name} className="expert-portrait" /><span><strong className="expert-name">{expert.name}</strong><small>IBCLC · 哺乳顾问</small></span></> : <><span className="expert-team-portraits" aria-hidden="true">{serviceExpertTeam.slice(0, 2).map((item) => <img key={item.id} src={item.avatar} alt="" />)}</span><span><strong className="expert-name">IBCLC 专家团队</strong><small>预约时确认本次专家</small></span></>}</div>}
            appointment={confirmedAppointment} appointmentLabel={confirmedAppointment?.consultationSequenceLabel ?? '首次咨询'}
            appointmentTime={confirmedAppointment ? `${formatAppointmentDay(confirmedAppointment.start, confirmedAppointment.timezone)} · ${formatAppointmentRange(confirmedAppointment.start, confirmedAppointment.end, confirmedAppointment.timezone)}` : undefined}
            nextStep={appointment?.attendanceOutcome ? (canBookConsultation ? '本次未扣次数，可重新预约' : '咨询权益已用完') : canBookConsultation ? '可预约下一次咨询' : '本服务包的咨询权益已用完'}
            actionLabel={showsConsultPreparation ? '查看预约' : appointmentAction.label} actionDisabled={!showsConsultPreparation && !appointmentAction.path}
            onAction={() => { if (showsConsultPreparation) setAppointmentDetailEpisodeId(episode.id); else if (appointmentAction.path) activateService(packageItem.id, appointmentAction.path, episode.id) }}
            onProgress={() => activateService(packageItem.id, progressPath, episode.id)} />
        })}
      </div> : <button className="home-support-entry" onClick={() => navigate('/app/services')} aria-label="查看专家支持方案，当前开放四类泌乳支持">
        <span className="home-support-icon"><Icon name="users" /></span>
        <span className="home-support-copy"><span><strong>按需选择专家支持</strong></span><small>当前 4 类泌乳方案 · 更多方向陆续加入</small></span>
        <Icon name="arrow" />
      </button>}
    </section>
    <section className="home-tools-section" aria-labelledby="home-tools-title">
      <div className="home-section-heading"><h2 id="home-tools-title"><Icon name="grid" />其它功能</h2></div>
      <div className="home-tool-groups">
        <div className="home-tool-group lactation-tools">
          <div className="home-tool-group-heading"><span className="home-tool-icon lactation"><Icon name="drop" /></span><h3>泌乳管理</h3></div>
          <div className="home-tool-items">
            <button className="home-tool-row disabled" disabled><span>奶量评估</span><small><Icon name="lock" />即将开放</small></button>
            <button className="home-tool-row disabled" disabled><span>奶量趋势</span><small><Icon name="lock" />即将开放</small></button>
          </div>
        </div>
        <div className="home-tool-group recovery-tools">
          <div className="home-tool-group-heading"><span className="home-tool-icon body"><Icon name="heart" /></span><h3>身体恢复</h3></div>
          <div className="home-tool-items"><button className="home-tool-row disabled" disabled><span>产后身体评估</span><small><Icon name="lock" />即将开放</small></button></div>
        </div>
      </div>
    </section>
    {statusRecordChoiceOpen && <Modal title="记录我的状态" className="my-status-record-dialog" closeIcon onClose={() => setStatusRecordChoiceOpen(false)}><p>选择这次想记录的内容</p><button type="button" onClick={() => { setStatusRecordChoiceOpen(false); openStatusEditor() }}>身体与心情<span>休息、身体精力和今日心情</span></button><button type="button" onClick={() => { setStatusRecordChoiceOpen(false); openLactationModal(true) }}>泌乳记录<span>泵奶与亲喂</span></button></Modal>}
    {appointmentDetail?.appointment && appointmentDetail.appointment.status === 'confirmed' && <Modal title="预约详情" className="expert-appointment-dialog" closeIcon onClose={() => setAppointmentDetailEpisodeId(undefined)}><HomeConsultPreparation appointment={appointmentDetail.appointment} onCancel={() => { setAppointmentDetailEpisodeId(undefined); requestCancelAppointment(appointmentDetail.packageItem.id, appointmentDetail.appointment!) }} onStart={() => { setAppointmentDetailEpisodeId(undefined); openStartConsult(appointmentDetail.packageItem.id, appointmentDetail.appointment!.id) }} /></Modal>}
    {momKnowledgeOpen && <DailyKnowledgeModal
      title="更好地了解自己的身体"
      article={dailyMomKnowledge}
      boundary="内容用于帮助理解你的连续记录，不是对身体或心理状态的诊断。"
      onClose={() => setMomKnowledgeOpen(false)}
      onAsk={() => { setMomKnowledgeOpen(false); navigate('/app/agent') }}
    />}
    {(statusEditorOpen || lactationModalOpen) && <Modal title={lactationModalOpen ? '今日泌乳' : diaryView.title} closeIcon={!lactationModalOpen} className={lactationModalOpen ? `milk-modal${lactationFormOpen ? ' milk-is-editing' : ''}` : `mom-diary-modal diary-${activeDiaryTab}`} onClose={() => lactationModalOpen ? setLactationModalOpen(false) : setStatusEditorOpen(false)}>{lactationModalOpen ? <div className="milk-hero" aria-hidden="true" /> : <div className="me-diary-intro">
      <div className="diary-editor-meta"><span>{formatPostpartumDay(state.user.postpartumDay)} · {new Date().getMonth() + 1}/{new Date().getDate()}</span><strong aria-label={`今日已记录 ${completedDiaryTabs} 项，共 3 项`}>{completedDiaryTabs}/3 已记录</strong></div>
      <p>{diaryView.description}</p><span className="me-diary-illustration" aria-hidden="true"><Icon name={diaryView.icon} /></span>
    </div>}<div className="mom-status-editor diary-editor">
      {!lactationModalOpen && <>
        <div className="diary-tabs" role="tablist" aria-label="今日状态分类" onKeyDown={(event) => {
          if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return
          event.preventDefault()
          const index = diaryTabs.findIndex((tab) => tab.id === activeDiaryTab)
          const next = event.key === 'Home' ? 0 : event.key === 'End' ? diaryTabs.length - 1 : (index + (event.key === 'ArrowRight' ? 1 : -1) + diaryTabs.length) % diaryTabs.length
          setActiveDiaryTab(diaryTabs[next].id)
          document.getElementById(`diary-tab-${diaryTabs[next].id}`)?.focus()
        }}>
          {diaryTabs.map((tab) => <button key={tab.id} id={`diary-tab-${tab.id}`} role="tab" tabIndex={activeDiaryTab === tab.id ? 0 : -1} aria-controls={`diary-panel-${tab.id}`} aria-selected={activeDiaryTab === tab.id} className={activeDiaryTab === tab.id ? 'active' : ''} onClick={() => setActiveDiaryTab(tab.id)}><span>{tab.label}</span>{diaryCompletion[tab.id] && <i aria-label="已记录" />}</button>)}
        </div>
      </>}
      <div key={activeDiaryTab} id={`diary-panel-${activeDiaryTab}`} className="diary-panel" role="tabpanel" aria-label={activeDiaryTab === 'lactation' ? '今日泌乳' : undefined} aria-labelledby={activeDiaryTab === 'lactation' ? undefined : `diary-tab-${activeDiaryTab}`}>
        {activeDiaryTab === 'rest' && <div className="diary-tab-content rest-tab-content">
          <div className="diary-question">
            <div className="diary-question-heading"><strong>昨夜大约睡了多久</strong></div>
            <div className="rest-choice-grid" role="group" aria-label="昨夜大约睡了多久">
              {(Object.keys(sleepTotalBandLabels) as MomSleepTotalBand[]).map((value) => <button key={value} type="button" aria-pressed={sleepTotalBand === value} className={sleepTotalBand === value ? 'selected' : ''} onClick={() => setSleepTotalBand(value)}>{sleepTotalBandLabels[value]}</button>)}
            </div>
          </div>
          <div className="diary-question">
            <div className="diary-question-heading"><strong>夜里大约被打断几次</strong></div>
            <div className="rest-choice-grid rest-interruption-grid" role="group" aria-label="夜里大约被打断几次">
              {(Object.keys(sleepInterruptionLabels) as MomSleepInterruptions[]).map((value) => <button key={value} type="button" aria-pressed={sleepInterruptions === value} className={sleepInterruptions === value ? 'selected' : ''} onClick={() => setSleepInterruptions(value)}>{sleepInterruptionLabels[value]}</button>)}
            </div>
          </div>
          <div className="diary-question">
            <div className="diary-question-heading"><strong>今天醒来时感觉怎样</strong></div>
            <div className="segmented diary-segmented rest-recovery" role="group" aria-label="今天醒来时感觉怎样">
              {(Object.keys(sleepRecoveryLabels) as MomSleepRecovery[]).map((value) => <button key={value} type="button" aria-pressed={sleepRecovery === value} className={sleepRecovery === value ? 'selected' : ''} onClick={() => setSleepRecovery(value)}>{sleepRecoveryLabels[value]}</button>)}
            </div>
          </div>
          <details className="rest-optional">
            <summary><span>补充休息情况</span><span>{[sleepStretchBand, dayRestBand, resleepDifficulty, restDisruptions.length ? 'has-reason' : ''].filter(Boolean).length ? '已填写' : '可选'}</span><span className="details-chevron">⌄</span></summary>
            <div className="rest-optional-body">
              <div className="diary-question">
                <div className="diary-question-heading"><strong>最长一段完整休息</strong></div>
                <div className="rest-choice-grid" role="group" aria-label="最长一段完整休息">
                  {(Object.keys(sleepStretchLabels) as MomSleepStretchBand[]).map((value) => <button key={value} type="button" aria-pressed={sleepStretchBand === value} className={sleepStretchBand === value ? 'selected' : ''} onClick={() => setSleepStretchBand(value)}>{sleepStretchLabels[value]}</button>)}
                </div>
              </div>
              <div className="diary-question">
                <div className="diary-question-heading"><strong>今天有没有一段不被打扰的休息</strong></div>
                <div className="rest-choice-grid day-rest-grid" role="group" aria-label="今天有没有一段不被打扰的休息">
                  {(Object.keys(dayRestLabels) as MomDayRestBand[]).map((value) => <button key={value} type="button" aria-pressed={dayRestBand === value} className={dayRestBand === value ? 'selected' : ''} onClick={() => setDayRestBand(value)}>{dayRestLabels[value]}</button>)}
                </div>
              </div>
              <div className="diary-question">
                <div className="diary-question-heading"><strong>醒来后容易再睡着吗</strong></div>
                <div className="segmented diary-segmented" role="group" aria-label="醒来后容易再睡着吗">
                  {(Object.keys(resleepLabels) as MomResleepDifficulty[]).map((value) => <button key={value} type="button" aria-pressed={resleepDifficulty === value} className={resleepDifficulty === value ? 'selected' : ''} onClick={() => setResleepDifficulty(value)}>{resleepLabels[value]}</button>)}
                </div>
              </div>
              <div className="diary-question">
                <div className="diary-question-heading"><strong>影响休息的原因</strong><span>可多选</span></div>
                <div className="tag-grid rest-reason-grid" role="group" aria-label="影响休息的原因">
                  {(Object.keys(restDisruptionLabels) as MomRestDisruption[]).map((value) => <button key={value} type="button" aria-pressed={restDisruptions.includes(value)} className={restDisruptions.includes(value) ? 'selected' : ''} onClick={() => setRestDisruptions((current) => current.includes(value) ? current.filter((item) => item !== value) : [...current, value])}>{restDisruptionLabels[value]}</button>)}
                </div>
              </div>
            </div>
          </details>
        </div>}
        {activeDiaryTab === 'body' && <div className="diary-tab-content body-tab-content">
          <div className="diary-question"><div className="diary-question-heading"><strong>今天身体的电量</strong><span>不和别人比较</span></div><div className="tag-grid body-energy-grid" role="group" aria-label="今天身体的电量">{(Object.keys(bodyEnergyLabels) as MomBodyEnergy[]).map((value) => <button key={value} type="button" aria-pressed={bodyEnergy === value} className={bodyEnergy === value ? 'selected' : ''} onClick={() => setBodyEnergy(value)}>{bodyEnergyLabels[value]}</button>)}</div></div>
          <div className="diary-question"><div className="diary-question-heading"><strong>今天哪里最需要照顾？</strong><span>可多选</span></div><div className="tag-grid">{(Object.keys(discomfortSiteLabels) as MomBodyDiscomfortSite[]).map((value) => <button key={value} type="button" aria-pressed={discomfortSites.includes(value)} className={discomfortSites.includes(value) ? 'selected' : ''} onClick={() => setDiscomfortSites((current) => current.includes(value) ? current.filter((item) => item !== value) : [...current, value])}>{discomfortSiteLabels[value]}</button>)}</div></div>
          {discomfortSites.length > 0 && <div className="diary-question"><div className="diary-question-heading"><strong>这种不适有多难受？</strong></div><div className="tag-grid body-small-grid" role="group" aria-label="这种不适有多难受">{(Object.keys(discomfortSeverityLabels) as MomBodyDiscomfortSeverity[]).map((value) => <button key={value} type="button" aria-pressed={discomfortSeverity === value} className={discomfortSeverity === value ? 'selected' : ''} onClick={() => setDiscomfortSeverity(value)}>{discomfortSeverityLabels[value]}</button>)}</div></div>}
          {discomfortSites.length > 0 && <div className="diary-question"><div className="diary-question-heading"><strong>这种不适影响到你了吗？</strong></div><div className="tag-grid body-small-grid" role="group" aria-label="这种不适影响到你了吗">{(Object.keys(bodyImpactLabels) as MomBodyImpact[]).map((value) => <button key={value} type="button" aria-pressed={bodyImpact === value} className={bodyImpact === value ? 'selected' : ''} onClick={() => setBodyImpact(value)}>{bodyImpactLabels[value]}</button>)}</div></div>}
          <div className="diary-question"><div className="diary-question-heading"><strong>和昨天相比，身体感觉</strong></div><div className="segmented diary-segmented" role="group" aria-label="和昨天相比，身体感觉">{(Object.keys(bodyTrendLabels) as MomBodyTrend[]).map((value) => <button key={value} type="button" aria-pressed={recoveryTrend === value} className={recoveryTrend === value ? 'selected' : ''} onClick={() => setRecoveryTrend(value)}>{bodyTrendLabels[value]}</button>)}</div></div>
          <details className="rest-optional body-optional"><summary><span>如厕与盆底</span><span>可选</span><span className="details-chevron">⌄</span></summary><div className="rest-optional-body"><div className="diary-question"><div className="diary-question-heading"><strong>排尿</strong></div><div className="tag-grid body-small-grid">{(Object.keys(urinationLabels) as MomUrination[]).map((value) => <button key={value} type="button" aria-pressed={urination === value} className={urination === value ? 'selected' : ''} onClick={() => setUrination(value)}>{urinationLabels[value]}</button>)}</div></div><div className="diary-question"><div className="diary-question-heading"><strong>排便</strong></div><div className="tag-grid body-small-grid">{(Object.keys(bowelLabels) as MomBowel[]).map((value) => <button key={value} type="button" aria-pressed={bowel === value} className={bowel === value ? 'selected' : ''} onClick={() => setBowel(value)}>{bowelLabels[value]}</button>)}</div></div></div></details>
          <label className="diary-text-field"><span>今天身体最想告诉你什么？ <em>可选</em></span><textarea rows={2} value={bodyNote} onChange={(event) => setBodyNote(event.target.value)} placeholder="例如：下床时伤口有点牵扯，坐久了会不舒服" /></label>
        </div>}
        {activeDiaryTab === 'mood' && <div className="diary-tab-content mood-tab-content">
          <div className="diary-question"><div className="diary-question-heading"><strong>今天心里更接近哪一种</strong><span>可以说不清楚</span></div><div className="tag-grid mood-tone-grid" role="group" aria-label="今天心里更接近哪一种">{(Object.keys(moodToneLabels) as MomMoodTone[]).map((value) => <button key={value} type="button" aria-pressed={moodTone === value} className={moodTone === value ? 'selected' : ''} onClick={() => setMoodTone(value)}>{moodToneLabels[value]}</button>)}</div></div>
          <div className="diary-question"><div className="diary-question-heading"><strong>什么一直占据着你的心？</strong><span>可多选</span></div><div className="tag-grid mood-pressure-grid" role="group" aria-label="什么一直占据着你的心">{(Object.keys(moodPressureLabels) as MomMoodPressure[]).map((value) => <button key={value} type="button" aria-pressed={moodPressures.includes(value)} className={moodPressures.includes(value) ? 'selected' : ''} onClick={() => setMoodPressures((current) => {
            if (value === 'unclear') return current.includes(value) ? [] : ['unclear']
            const withoutUnclear = current.filter((item) => item !== 'unclear')
            return withoutUnclear.includes(value) ? withoutUnclear.filter((item) => item !== value) : [...withoutUnclear, value]
          })}>{moodPressureLabels[value]}</button>)}</div></div>
          <div className="diary-question"><div className="diary-question-heading"><strong>这份难受影响到你了吗？</strong></div><div className="tag-grid mood-impact-grid" role="group" aria-label="这份难受影响到你了吗">{(Object.keys(moodImpactLabels) as MomMoodFunctionImpact[]).map((value) => <button key={value} type="button" aria-pressed={moodFunctionImpact === value} className={moodFunctionImpact === value ? 'selected' : ''} onClick={() => setMoodFunctionImpact(value)}>{moodImpactLabels[value]}</button>)}</div></div>
          <div className="diary-question"><div className="diary-question-heading"><strong>今天有人接住你吗？</strong></div><div className="tag-grid mood-support-grid" role="group" aria-label="今天有人接住你吗">{(Object.keys(moodSupportLabels) as MomMoodSupport[]).map((value) => <button key={value} type="button" aria-pressed={moodSupport === value} className={moodSupport === value ? 'selected' : ''} onClick={() => setMoodSupport(value)}>{moodSupportLabels[value]}</button>)}</div></div>
        </div>}
        {activeDiaryTab === 'lactation' && <div className="diary-tab-content lactation-tab-content">
          {!lactationFormOpen ? <>
            {lactationModalOpen && <MeMilkTrend records={state.lactationRecords.map((record) => ({ date: record.occurredAt, amount: recordPumpVolume(record) }))} />}
            <section className="lactation-day-summary" aria-label="今日泌乳汇总">
              <div className="lactation-summary-heading"><div><strong>今日汇总</strong>{latestLactationTime && <span>最近 {latestLactationTime}</span>}</div><Button size="sm" variant="soft" onClick={() => beginLactationRecord()}>+ 添加一条</Button></div>
              <div className="lactation-summary-grid"><div><span>泵奶</span><strong>{pumpSummary}</strong></div><div><span>亲喂</span><strong>{nursingSummary}</strong></div></div>
            </section>
            {lactationMessage && <div className="inline-success lactation-feedback" role="status"><Icon name="check" /><span>{lactationMessage}</span></div>}
            {deletedLactationRecord && <div className="inline-warning lactation-feedback" role="status"><Icon name="clock" /><span>记录已删除</span><button className="text-button" onClick={undoRemoveLactationRecord}>撤销</button></div>}
            {todayLactationRecords.length ? <div className="lactation-timeline" role="list" aria-label="今天的泌乳记录">{todayLactationRecords.map((record) => <article className="lactation-record-row" role="listitem" key={record.id}>
              <time dateTime={record.occurredAt}>{new Date(record.occurredAt).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}</time>
              <div className={`lactation-record-icon ${record.method}`}><Icon name={record.method === 'pump' ? 'drop' : 'baby'} /></div>
              <div className="lactation-record-copy"><strong>{lactationMethodLabels[record.method]} · {lactationRecordSideLabel(record)}</strong><span>{lactationRecordDetail(record)}{record.feeling ? ` · ${breastComfortLabels[record.feeling]}` : ''}</span>{record.note && <p>{record.note}</p>}</div>
              <div className="lactation-record-actions"><button type="button" onClick={() => beginLactationRecord(record)}>编辑</button><button type="button" className="danger" onClick={() => removeLactationRecord(record)}>删除</button></div>
            </article>)}</div> : <div className="lactation-empty"><Icon name="drop" /><div><strong>{legacyLactationRecordedToday ? '今天已有一笔汇总' : '今天还没有泌乳记录'}</strong><span>{legacyLactationRecordedToday ? '新的记录会从下一次开始按次保存。' : '添加一次泵奶或亲喂即可。'}</span></div></div>}
          </> : <div className="lactation-entry-form">
            <div className="lactation-form-heading"><div><strong>{editingLactationId ? '编辑这次记录' : '添加一条记录'}</strong></div>{lactationRecordedToday && <button className="text-button" type="button" onClick={exitLactationForm}>返回记录</button>}</div>
            <div className="diary-question"><div className="diary-question-heading"><strong>记录方式</strong></div><div className="segmented diary-segmented" role="group" aria-label="泌乳方式">{(Object.keys(lactationMethodLabels) as LactationMethod[]).map((value) => <button key={value} type="button" aria-pressed={lactationMethod === value} className={lactationMethod === value ? 'selected' : ''} onClick={() => changeLactationMethod(value)}>{lactationMethodLabels[value]}</button>)}</div></div>
            <div className="lactation-core-grid"><label className="mom-editor-field"><span>时间</span><div className="unit-input"><input aria-label="记录时间" type="time" value={lactationTime} onChange={(event) => { setLactationTime(event.target.value); setLactationError('') }} /></div></label><div className="mom-editor-field"><span>侧别</span><div className="lactation-side-grid" role="group" aria-label="泌乳侧别">{lactationSides.map((value) => <button key={value} type="button" aria-pressed={lactationSide === value} className={lactationSide === value ? 'selected' : ''} onClick={() => { setLactationSide(value); setLactationError('') }}>{lactationSideLabels[value]}</button>)}</div></div></div>
            {lactationMethod === 'pump' && <label className="mom-editor-field"><span>{lactationSide === 'left' ? '左侧奶量' : '右侧奶量'} <em>可选</em></span><div className="unit-input"><input aria-label={lactationSide === 'left' ? '左侧奶量' : '右侧奶量'} type="number" min="0" max="2000" step="1" value={lactationSide === 'left' ? leftVolumeMl : rightVolumeMl} onChange={(event) => lactationSide === 'left' ? setLeftVolumeMl(event.target.value) : setRightVolumeMl(event.target.value)} placeholder="—" /><em>ml</em></div></label>}
            {lactationMethod === 'nurse' && <label className="mom-editor-field"><span>{lactationSide === 'left' ? '左侧时长' : '右侧时长'} <em>可选</em></span><div className="unit-input"><input aria-label={lactationSide === 'left' ? '左侧亲喂时长' : '右侧亲喂时长'} type="number" min="0" max="240" step="1" value={lactationSide === 'left' ? leftDurationMinutes : rightDurationMinutes} onChange={(event) => lactationSide === 'left' ? setLeftDurationMinutes(event.target.value) : setRightDurationMinutes(event.target.value)} placeholder="—" /><em>分钟</em></div></label>}
            <details className="lactation-optional"><summary><span>补充感受与备注</span><span>{lactationFeeling || lactationNote ? '已填写' : '可选'}</span><span className="details-chevron">⌄</span></summary><div className="lactation-optional-body"><div className="diary-question"><div className="diary-question-heading"><strong>本次乳房感受</strong></div><div className="tag-grid breast-tag-grid">{(Object.keys(breastComfortLabels) as MomBreastComfort[]).map((value) => <button key={value} type="button" aria-pressed={lactationFeeling === value} className={lactationFeeling === value ? 'selected' : ''} onClick={() => setLactationFeeling((current) => current === value ? '' : value)}>{breastComfortLabels[value]}</button>)}</div></div><label className="diary-text-field"><span>备注 <em>可选</em></span><textarea aria-label="本次泌乳备注" rows={2} value={lactationNote} onChange={(event) => setLactationNote(event.target.value)} placeholder="例如：右侧有些胀" /></label></div></details>
            {lactationError && <div className="mom-editor-error" role="alert"><Icon name="clock" /><span>{lactationError}</span></div>}
            <div className="lactation-form-actions"><Button variant="soft" onClick={exitLactationForm}>取消</Button><Button onClick={saveLactationRecord}>{editingLactationId ? '保存修改' : '保存这次记录'}</Button></div>
          </div>}
        </div>}
      </div>
      {activeDiaryTab !== 'lactation' && <>{statusError && <div className="mom-editor-error" role="alert"><Icon name="clock" /><span>{statusError}</span></div>}<Button size="lg" onClick={saveMomStatus}>保存今天的记录</Button></>}
    </div></Modal>}
    {deviceCheckPackageId && <DeviceCheckModal onClose={() => setDeviceCheckPackageId(undefined)} onSuccess={() => { const packageId = deviceCheckPackageId; setDeviceCheckPackageId(undefined); setStartConsultPackageId(packageId) }} />}
    {startConsultPackageId && state.appointment && <StartConsultModal initialLocation={state.bookingPrecheck.state || state.user.state} consentReady={state.consent.status === 'active' && state.consent.scopes.includes('video')} busy={consultation.busy} error={consultation.error} onClose={() => { consultation.clearError(); setStartConsultPackageId(undefined) }} onRestoreConsent={() => navigate('/app/privacy')} onEnter={async (stateCode) => { const appointmentId = state.appointment?.id; if (!appointmentId) return false; const entered = await consultation.verifyLocationAndJoin(appointmentId, stateCode); if (!entered) return false; setStartConsultPackageId(undefined); navigate(`/app/consult/${appointmentId}/room`); return true }} />}
    {cancelAppointmentTarget && <Modal title="取消预约" className="booking-cancel-modal" showClose={!consultation.busy} onClose={() => { if (!consultation.busy) { consultation.clearError(); setCancelAppointmentTarget(undefined) } }}><div className="booking-cancel-content"><div className="booking-cancel-summary"><span className="booking-cancel-icon"><Icon name="calendar" /></span><div><strong>{formatAppointmentDay(cancelAppointmentTarget.start, cancelAppointmentTarget.timezone)} · {formatAppointmentRange(cancelAppointmentTarget.start, cancelAppointmentTarget.end, cancelAppointmentTarget.timezone)}</strong><AssignedExpertIdentity expertId={cancelAppointmentTarget.ibclcId} expertName={cancelAppointmentTarget.ibclcName} label="本次咨询专家" /></div></div><p>取消后，该时段将释放。重新预约时需要再次确认信息采集表，已填写内容会保留。</p>{consultation.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{consultation.error}</span></div>}<div className="booking-cancel-actions"><Button size="lg" disabled={consultation.busy} onClick={() => setCancelAppointmentTarget(undefined)}>保留预约</Button><Button size="lg" variant="danger" disabled={consultation.busy} onClick={() => { void cancelHomeAppointment() }}>{consultation.busy ? '正在取消…' : '确认取消'}</Button></div></div></Modal>}
  </div>
}

type BabyLogMode = 'feeding' | 'diaper' | 'sleep' | 'growth' | 'development'

type BabyFeedbackUndo =
  | { kind: 'feeding' | 'diaper' | 'sleep'; id: string }
  | { kind: 'growth'; ids: string[] }
type BabyFeedingType = Exclude<FeedingRecord['type'], '泵奶'>
type BabyKnowledgeTopic = 'feeding' | 'feeding-cues' | 'sleep' | 'diaper' | 'growth' | 'development'

type BabyKnowledgeArticle = DailyKnowledgeArticle & {
  sourceLabel: string
  sourceUrl: string
}

const babyKnowledgeArticles: Record<BabyKnowledgeTopic, BabyKnowledgeArticle> = {
  feeding: {
    title: '每一顿不必一样，连续记录更有意义',
    summary: '喂养次数、间隔和实际记录的奶量各自说明不同的事。把几天的记录放在一起看，比盯住某一顿更容易理解宝宝的节奏。',
    points: [
      '先看每次发生的时间和一天的次数，不需要追求完全整齐的间隔。',
      '瓶喂量只代表实际填写的毫升数；亲喂时长不能直接换算成摄入量。',
      '如果担心宝宝吃得太多或太少，把连续记录带给儿科医生或喂养专业人员一起判断。'
    ],
    icon: 'baby',
    sourceLabel: 'CDC · 婴幼儿营养',
    sourceUrl: 'https://www.cdc.gov/infant-toddler-nutrition/breastfeeding/how-much-and-how-often.html'
  },
  'feeding-cues': {
    title: '比时间表更早出现的，是宝宝的饥饱信号',
    summary: '新生宝宝会用动作表达需要。把记录时间和当时看到的信号放在一起回想，能更从容地认识宝宝自己的节奏。',
    points: [
      '手靠近嘴、转头寻找乳房或奶瓶、咂嘴，可能是在表达饥饿。',
      '闭嘴、转开头或双手放松，可能是在表达已经吃饱。',
      '每个宝宝都不完全一样；连续观察比用一次表现下结论更可靠。'
    ],
    icon: 'heart',
    sourceLabel: 'CDC · 饥饿与饱足信号',
    sourceUrl: 'https://www.cdc.gov/infant-toddler-nutrition/mealtime/signs-your-child-is-hungry-or-full.html'
  },
  sleep: {
    title: '记录睡眠，也要把安全睡眠放在第一位',
    summary: '睡眠段数和时长帮助你看见节奏；睡眠姿势与环境则需要每一次都重新确认。',
    points: [
      '每次睡眠都让宝宝仰卧，并使用坚实、平坦的睡眠表面。',
      '睡眠区域只保留合身床单，不放枕头、松软被褥、防撞垫或毛绒玩具。',
      '起止时间适合用来统计总时长和最长连续睡眠，但不能代替对睡眠环境的检查。'
    ],
    icon: 'moon',
    sourceLabel: 'CDC · 婴儿安全睡眠',
    sourceUrl: 'https://www.cdc.gov/sudden-infant-death/sleep-safely/'
  },
  diaper: {
    title: '尿布里的连续变化，比单次印象更有信息',
    summary: '尿湿次数、便便时间、颜色和性状分开记录，之后回看或与医生沟通时会更清楚。',
    points: [
      '按次记录实际看到的尿湿或便便，不确定颜色或性状时不需要猜。',
      '便便频率本来就可能有较大差异，连续变化通常比某一次更值得回看。',
      '若明确看到红色、灰白色，或已过最初胎便阶段仍是黑色，应尽快联系儿科医生确认。'
    ],
    icon: 'drop',
    sourceLabel: 'AAP HealthyChildren · 婴儿便便颜色',
    sourceUrl: 'https://www.healthychildren.org/english/ages-stages/baby/pages/the-many-colors-of-poop.aspx'
  },
  growth: {
    title: '看成长，关键是同一口径下的连续变化',
    summary: '体重、身长和头围需要结合年龄与连续测量来理解，单独一个数字不能说明宝宝的生长状态。',
    points: [
      '尽量在相近条件下测量，并记下实际测量日期。',
      '先比较一段时间内的变化，不用让一次波动替你下结论。',
      '正式评估应由专业人员结合标准生长曲线、喂养和整体情况完成。'
    ],
    icon: 'plan',
    sourceLabel: 'WHO · 儿童生长标准',
    sourceUrl: 'https://www.who.int/tools/child-growth-standards/standards'
  },
  development: {
    title: '一次没看到，不等于宝宝不会',
    summary: '发育观察适合记录带日期的具体行为，而不是给宝宝打分。持续观察会比一次结果更接近真实情况。',
    points: [
      '只写你实际看到的动作、声音或反应，并保留观察日期。',
      '“尚未观察到”只描述这一次，不应直接解释为宝宝做不到。',
      '里程碑清单不能代替标准化发育筛查；有担心时应和宝宝的医生沟通。'
    ],
    icon: 'spark',
    sourceLabel: 'CDC · 婴幼儿发育里程碑',
    sourceUrl: 'https://www.cdc.gov/act-early/milestones/2-months.html'
  }
}

const babyLogLabels: Record<BabyLogMode, string> = {
  feeding: '今日吃奶',
  diaper: '尿布与便便',
  sleep: '睡眠',
  growth: '生长发育',
  development: '发育观察'
}

const babyStoolColorLabels: Record<BabyStoolColor, string> = {
  yellow: '黄色',
  'yellow-brown': '黄褐色',
  green: '绿色',
  brown: '褐色',
  black: '黑色',
  red: '红色',
  pale: '灰白色',
  unsure: '不确定'
}

const babyStoolConsistencyLabels: Record<BabyStoolConsistency, string> = {
  watery: '水样',
  loose: '稀软',
  pasty: '糊状',
  formed: '成形',
  hard: '颗粒或硬球',
  unsure: '不确定'
}

const babyGrowthMetricLabels: Record<BabyGrowthMetric, string> = {
  weight: '体重',
  length: '身长',
  'head-circumference': '头围'
}

const emptyBabyGrowthValues = (): Record<BabyGrowthMetric, string> => ({
  weight: '',
  length: '',
  'head-circumference': ''
})

const babyDevelopmentStatusLabels: Record<BabyDevelopmentStatus, string> = {
  observed: '观察到',
  'not-observed': '尚未观察到',
  unsure: '不确定'
}

const babyDevelopmentItems = [
  { id: 'looks-at-face', label: '看向靠近的脸' },
  { id: 'responds-to-sound', label: '听到声音后有动作或表情反应' },
  { id: 'lifts-head', label: '俯卧时短暂抬起头' }
] as const

function formatBabyClock(value: string) {
  return new Date(value).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
}

function formatBabyDuration(minutes: number) {
  if (minutes < 1) return '不到 1 分钟'
  if (minutes < 60) return `${minutes} 分钟`
  const hours = Math.floor(minutes / 60)
  const rest = minutes % 60
  return `${hours} 小时${rest ? ` ${rest} 分` : ''}`
}

function localDateTimeValue(date = new Date()) {
  const offset = date.getTimezoneOffset() * 60000
  return new Date(date.getTime() - offset).toISOString().slice(0, 16)
}

function formatBabyDate(value: string) {
  return new Date(value).toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric' })
}

type BabyGrowthChartMetric = BabyGrowthMetric

type WhoGrowthChartConfig = {
  label: string
  unit: 'kg' | 'cm'
  domain: readonly [number, number]
  ticks: readonly number[]
}

const babyGrowthChartMetrics: BabyGrowthChartMetric[] = ['weight', 'length', 'head-circumference']
const babySexLabels: Record<Exclude<BabySex, 'unspecified'>, string> = { female: '女宝宝', male: '男宝宝' }

const whoGrowthChartConfig: Record<BabyGrowthChartMetric, WhoGrowthChartConfig> = {
  weight: {
    label: '体重',
    unit: 'kg',
    domain: [2, 10],
    ticks: [2, 4, 6, 8, 10],
  },
  length: {
    label: '身长',
    unit: 'cm',
    domain: [44, 75],
    ticks: [45, 55, 65, 75],
  },
  'head-circumference': {
    label: '头围',
    unit: 'cm',
    domain: [30, 48],
    ticks: [30, 36, 42, 48],
  }
}

function BabyGrowthCurve({ metric, records, babyName, birthDate, sex, onMetricChange, onEditProfile }: {
  metric: BabyGrowthChartMetric
  records: BabyGrowthRecord[]
  babyName: string
  birthDate: string
  sex: BabySex
  onMetricChange: (metric: BabyGrowthChartMetric) => void
  onEditProfile: () => void
}) {
  const config = whoGrowthChartConfig[metric]
  const chart = { left: 29, right: 326, top: 9, bottom: 91 }
  const maxAgeDays = calendarMonthAgeInDays(birthDate, WHO_GROWTH_MAX_MONTHS) ?? 183
  const xForAgeDays = (ageDays: number) => chart.left + (ageDays / maxAgeDays) * (chart.right - chart.left)
  const yForValue = (value: number) => {
    const [min, max] = config.domain
    const clamped = Math.min(max, Math.max(min, value))
    return chart.bottom - ((clamped - min) / (max - min)) * (chart.bottom - chart.top)
  }
  const referencePoints = whoGrowthReferencePoints(metric, sex, birthDate)
  const linePath = (valueForPoint: (point: typeof referencePoints[number]) => number) => referencePoints
    .map((point, index) => `${index ? 'L' : 'M'} ${xForAgeDays(point.ageDays).toFixed(1)} ${yForValue(valueForPoint(point)).toFixed(1)}`)
    .join(' ')
  const lowerPath = linePath((point) => point.lower)
  const upperPath = linePath((point) => point.upper)
  const bandPath = referencePoints.length ? `${lowerPath} ${[...referencePoints].reverse().map((point) => `L ${xForAgeDays(point.ageDays).toFixed(1)} ${yForValue(point.upper).toFixed(1)}`).join(' ')} Z` : ''
  const personalPoints = records
    .map((record) => ({ ageDays: growthRecordAgeInDays(birthDate, record.measuredAt), value: record.value }))
    .filter((point): point is { ageDays: number; value: number } => point.ageDays !== undefined && point.ageDays <= maxAgeDays)
    .sort((a, b) => a.ageDays - b.ageDays)
  const personalPath = personalPoints.map((point, index) => `${index ? 'L' : 'M'} ${xForAgeDays(point.ageDays).toFixed(1)} ${yForValue(point.value).toFixed(1)}`).join(' ')
  const sexLabel = sex === 'unspecified' ? '' : babySexLabels[sex]
  const ariaLabel = `出生至 6 月${config.label}趋势${sexLabel ? `，浅绿色区域是世界卫生组织提供的同龄${sexLabel}参考范围` : '，需要补充出生记录性别后显示生长参考范围'}${personalPoints.length ? `，深色线为 ${babyName} 的 ${personalPoints.length} 条记录` : ''}`

  return <div className="baby-growth-curve-card">
    <div className="baby-growth-curve-heading">
      <div><strong>生长趋势</strong><span>出生至 6 月{sexLabel ? ` · ${sexLabel}` : ''} · {config.unit}</span></div>
      <div className="baby-growth-curve-tabs" role="group" aria-label="切换生长趋势指标">
        {babyGrowthChartMetrics.map((item) => <button key={item} type="button" aria-pressed={metric === item} className={metric === item ? 'selected' : ''} onClick={() => onMetricChange(item)}>{babyGrowthMetricLabels[item]}</button>)}
      </div>
    </div>
    {referencePoints.length ? <svg className="baby-growth-curve-chart" viewBox="0 0 340 116" role="img" aria-label={ariaLabel}>
      {config.ticks.map((tick) => <g key={tick}>
        <line className="baby-growth-chart-grid" x1={chart.left} x2={chart.right} y1={yForValue(tick)} y2={yForValue(tick)} />
        <text className="baby-growth-chart-axis" x="23" y={yForValue(tick) + 3} textAnchor="end">{tick}</text>
      </g>)}
      <path className="baby-growth-chart-band" d={bandPath} />
      <path className="baby-growth-chart-boundary" d={lowerPath} />
      <path className="baby-growth-chart-boundary" d={upperPath} />
      {personalPoints.length > 1 && <path className="baby-growth-chart-personal-line" d={personalPath} />}
      {personalPoints.map((point, index) => <circle key={`${point.ageDays}-${point.value}-${index}`} className="baby-growth-chart-personal-point" cx={xForAgeDays(point.ageDays)} cy={yForValue(point.value)} r="4" />)}
      {[0, 2, 4, 6].map((month) => {
        const ageDays = calendarMonthAgeInDays(birthDate, month) ?? month / WHO_GROWTH_MAX_MONTHS * maxAgeDays
        return <text key={month} className="baby-growth-chart-axis month" x={xForAgeDays(ageDays)} y="109" textAnchor={month === 0 ? 'start' : month === 6 ? 'end' : 'middle'}>{month === 0 ? '出生' : `${month} 月`}</text>
      })}
    </svg> : <div className="baby-growth-reference-missing" role="status"><span>补充出生日期和出生记录性别后，才能显示对应的生长参考范围。</span><button className="text-button" type="button" onClick={onEditProfile}>完善资料</button></div>}
    {referencePoints.length > 0 && <p className="baby-growth-curve-note"><Icon name="shield" /><span>{personalPoints.length ? `深色线是 ${babyName} 的记录；` : `记录后会显示 ${babyName} 的变化；`}浅绿色是世界卫生组织提供的同龄{sexLabel}参考范围，适合看长期变化，不能根据一次记录下结论。</span></p>}
  </div>
}

function BabyPage() {
  const { state, dispatch } = useProduct()
  const navigate = useNavigate()
  const [logMode, setLogMode] = useState<BabyLogMode>()
  const [knowledgeOpen, setKnowledgeOpen] = useState(false)
  const [knowledgeReleasedAt, setKnowledgeReleasedAt] = useState(currentDailyKnowledgeRelease)
  const [eventTime, setEventTime] = useState(localTimeValue())
  const [feedingType, setFeedingType] = useState<BabyFeedingType | ''>('')
  const [feedingSide, setFeedingSide] = useState<FeedingRecord['breastSide'] | ''>('')
  const [feedingAmount, setFeedingAmount] = useState('')
  const [feedingDuration, setFeedingDuration] = useState('')
  const [diaperKind, setDiaperKind] = useState<'wet' | 'dirty' | 'both' | ''>('')
  const [stoolDiaperKind, setStoolDiaperKind] = useState<'dirty' | 'both'>('dirty')
  const [stoolColor, setStoolColor] = useState<BabyStoolColor | ''>('')
  const [stoolConsistency, setStoolConsistency] = useState<BabyStoolConsistency | ''>('')
  const [stoolVisibleSigns, setStoolVisibleSigns] = useState<BabyStoolVisibleSign[]>([])
  const [sleepStartedAt, setSleepStartedAt] = useState(localDateTimeValue())
  const [sleepEndedAt, setSleepEndedAt] = useState('')
  const [growthMetric, setGrowthMetric] = useState<BabyGrowthMetric>('weight')
  const [growthChartMetric, setGrowthChartMetric] = useState<BabyGrowthChartMetric>('weight')
  const [growthValues, setGrowthValues] = useState<Record<BabyGrowthMetric, string>>(emptyBabyGrowthValues)
  const [growthDate, setGrowthDate] = useState(localDateKey())
  const [developmentDate, setDevelopmentDate] = useState(localDateKey())
  const [developmentDraft, setDevelopmentDraft] = useState<Record<string, BabyDevelopmentStatus | ''>>({})
  const [feedingNote, setFeedingNote] = useState('')
  const [diaperNote, setDiaperNote] = useState('')
  const [sleepNote, setSleepNote] = useState('')
  const [logError, setLogError] = useState('')
  const [feedback, setFeedback] = useState<{ message: string; undo?: BabyFeedbackUndo }>()
  const [babySwitcherOpen, setBabySwitcherOpen] = useState(false)
  const [babyProfileOpen, setBabyProfileOpen] = useState(false)
  const [profileName, setProfileName] = useState(state.baby.name)
  const [profileBirthDate, setProfileBirthDate] = useState(state.baby.birthDate)
  const [profileSex, setProfileSex] = useState<BabySex>(state.baby.sex)
  const [profileError, setProfileError] = useState('')

  useEffect(() => {
    const nextRelease = nextDailyKnowledgeRelease()
    const timer = window.setTimeout(() => setKnowledgeReleasedAt(currentDailyKnowledgeRelease()), Math.max(1000, nextRelease.getTime() - Date.now()))
    return () => window.clearTimeout(timer)
  }, [knowledgeReleasedAt])

  const todayKey = localDateKey()
  const babyFeedingRecords = state.feedingRecords
    .filter((record) => record.babyId === state.baby.id && record.type !== '泵奶')
    .sort((a, b) => new Date(b.loggedAt).getTime() - new Date(a.loggedAt).getTime())
  const todayFeedingRecords = babyFeedingRecords.filter((record) => localDateKey(new Date(record.loggedAt)) === todayKey)
  const babyDiaperRecords = state.babyDiaperRecords
    .filter((record) => record.babyId === state.baby.id)
    .sort((a, b) => new Date(b.loggedAt).getTime() - new Date(a.loggedAt).getTime())
  const todayDiaperRecords = babyDiaperRecords.filter((record) => localDateKey(new Date(record.loggedAt)) === todayKey)
  const babySleepRecords = state.babySleepRecords
    .filter((record) => record.babyId === state.baby.id)
    .sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime())
  const nowTime = Date.now()
  const todayStart = new Date()
  todayStart.setHours(0, 0, 0, 0)
  const todayEnd = new Date(todayStart)
  todayEnd.setDate(todayEnd.getDate() + 1)
  const todaySleepRecords = babySleepRecords.filter((record) => {
    const startedAt = new Date(record.startedAt).getTime()
    const endedAt = record.endedAt ? new Date(record.endedAt).getTime() : nowTime
    return startedAt < todayEnd.getTime() && endedAt > todayStart.getTime()
  })
  const activeSleep = babySleepRecords.find((record) => !record.endedAt)
  const babyGrowthRecords = state.babyGrowthRecords
    .filter((record) => record.babyId === state.baby.id)
    .sort((a, b) => new Date(b.measuredAt).getTime() - new Date(a.measuredAt).getTime())
  const weightRecords = babyGrowthRecords.filter((record) => record.metric === 'weight')
  const lengthRecords = babyGrowthRecords.filter((record) => record.metric === 'length')
  const headCircumferenceRecords = babyGrowthRecords.filter((record) => record.metric === 'head-circumference')
  const latestWeight = weightRecords[0]
  const latestLength = lengthRecords[0]
  const latestHeadCircumference = headCircumferenceRecords[0]
  const babyDevelopmentRecords = state.babyDevelopmentRecords.filter((record) => record.babyId === state.baby.id)
  const wetDiapers = todayDiaperRecords.filter((record) => record.kind === 'wet' || record.kind === 'both').length
  const dirtyDiapers = todayDiaperRecords.filter((record) => record.kind === 'dirty' || record.kind === 'both').length
  const todaySleepDurations = todaySleepRecords.map((record) => {
    const start = Math.max(new Date(record.startedAt).getTime(), todayStart.getTime())
    const end = Math.min(record.endedAt ? new Date(record.endedAt).getTime() : nowTime, todayEnd.getTime())
    return Math.max(0, Math.round((end - start) / 60000))
  })
  const sleepMinutes = todaySleepDurations.reduce((total, minutes) => total + minutes, 0)
  const longestSleepMinutes = todaySleepDurations.length ? Math.max(...todaySleepDurations) : 0
  const lastDevelopmentCheck = babyDevelopmentRecords
    .map((record) => record.checkedAt)
    .sort((a, b) => new Date(b).getTime() - new Date(a).getTime())[0]
  const resetCommonDraft = () => {
    setEventTime(localTimeValue())
    setFeedingType('')
    setFeedingSide('')
    setFeedingAmount('')
    setFeedingDuration('')
    setDiaperKind('')
    setStoolDiaperKind('dirty')
    setStoolColor('')
    setStoolConsistency('')
    setStoolVisibleSigns([])
    setSleepStartedAt(localDateTimeValue())
    setSleepEndedAt('')
    setGrowthMetric('weight')
    setGrowthValues(emptyBabyGrowthValues())
    setGrowthDate(localDateKey())
    setDevelopmentDate(localDateKey())
    setDevelopmentDraft({})
    setFeedingNote('')
    setDiaperNote('')
    setSleepNote('')
    setLogError('')
  }
  const openLog = (mode: BabyLogMode, initialDiaperKind?: 'wet' | 'dirty') => {
    resetCommonDraft()
    if (mode === 'diaper' && initialDiaperKind) setDiaperKind(initialDiaperKind)
    if (mode === 'development') {
      setDevelopmentDraft(Object.fromEntries(babyDevelopmentRecords.map((record) => [record.itemId, record.status])))
      if (lastDevelopmentCheck) setDevelopmentDate(localDateKey(new Date(lastDevelopmentCheck)))
    }
    setLogMode(mode)
    setFeedback(undefined)
  }
  const openGrowthLog = (metric: BabyGrowthChartMetric = growthChartMetric) => {
    openLog('growth')
    setGrowthMetric(metric)
  }
  const switchStatusLog = (target: 'sleep' | 'wet' | 'stool') => {
    setLogError('')
    if (target === 'sleep') {
      setLogMode('sleep')
      return
    }
    setLogMode('diaper')
    setDiaperKind(target === 'wet' ? 'wet' : stoolDiaperKind)
  }
  const closeLog = () => { setLogMode(undefined); setLogError('') }
  const recordTime = () => {
    if (!eventTime) {
      setLogError('请选择记录时间。')
      return undefined
    }
    const date = todayAtTime(eventTime)
    if (date.getTime() > Date.now() + 60000) {
      setLogError('记录时间不能晚于现在。')
      return undefined
    }
    return date.toISOString()
  }
  const saveFeeding = () => {
    if (!feedingType) { setLogError('先选择这次的喂养方式。'); return }
    if (feedingType === '亲喂' && !feedingSide) { setLogError('请选择这次亲喂的侧别。'); return }
    const loggedAt = recordTime()
    if (!loggedAt) return
    const amount = feedingAmount.trim() ? Number(feedingAmount) : undefined
    const duration = feedingDuration.trim() ? Number(feedingDuration) : undefined
    if (amount !== undefined && (!Number.isFinite(amount) || amount <= 0 || amount > 1000)) { setLogError('请检查瓶喂量。'); return }
    if (duration !== undefined && (!Number.isFinite(duration) || duration <= 0 || duration > 240)) { setLogError('请检查亲喂时长。'); return }
    const id = `feeding-${Date.now()}`
    dispatch({ type: 'addFeedingRecord', record: { id, babyId: state.baby.id, type: feedingType, loggedAt, breastSide: feedingType === '亲喂' ? feedingSide || undefined : undefined, amountMl: feedingType === '亲喂' ? undefined : amount, durationMinutes: feedingType === '亲喂' ? duration : undefined, note: feedingNote.trim() || undefined } })
    closeLog()
    setFeedback({ message: '这次喂养的时间和已填写数值已记下。', undo: { kind: 'feeding', id } })
  }
  const saveDiaper = () => {
    if (!diaperKind) { setLogError('先选择这次换到的尿布。'); return }
    const loggedAt = recordTime()
    if (!loggedAt) return
    const id = `diaper-${Date.now()}`
    const hasStool = diaperKind === 'dirty' || diaperKind === 'both'
    dispatch({ type: 'addBabyDiaperRecord', record: {
      id,
      babyId: state.baby.id,
      kind: diaperKind,
      loggedAt,
      stoolColor: hasStool ? stoolColor || undefined : undefined,
      stoolConsistency: hasStool ? stoolConsistency || undefined : undefined,
      stoolVisibleSigns: hasStool && stoolVisibleSigns.length ? stoolVisibleSigns : undefined,
      note: diaperNote.trim() || undefined
    } })
    closeLog()
    setFeedback({ message: diaperKind === 'wet' ? '这次尿湿已记下。' : diaperKind === 'dirty' ? '这次便便已记下。' : '这次尿湿和便便已记下。', undo: { kind: 'diaper', id } })
  }
  const saveSleep = () => {
    if (!sleepStartedAt) { setLogError('请选择入睡时间。'); return }
    const started = new Date(sleepStartedAt)
    const ended = sleepEndedAt ? new Date(sleepEndedAt) : undefined
    if (!Number.isFinite(started.getTime()) || started.getTime() > Date.now() + 60000) { setLogError('入睡时间不能晚于现在。'); return }
    if (ended && (!Number.isFinite(ended.getTime()) || ended.getTime() > Date.now() + 60000)) { setLogError('醒来时间不能晚于现在。'); return }
    if (ended && ended.getTime() <= started.getTime()) { setLogError('醒来时间需要晚于入睡时间。'); return }
    const id = `baby-sleep-${Date.now()}`
    dispatch({ type: 'addBabySleepRecord', record: { id, babyId: state.baby.id, startedAt: started.toISOString(), endedAt: ended?.toISOString(), note: sleepNote.trim() || undefined } })
    closeLog()
    setFeedback({ message: ended ? `这段 ${formatBabyDuration(Math.round((ended.getTime() - started.getTime()) / 60000))}的睡眠已记下。` : '已开始记录这段睡眠，醒来时结束即可。', undo: { kind: 'sleep', id } })
  }
  const endSleep = () => {
    if (!activeSleep) return
    dispatch({ type: 'endBabySleepRecord', id: activeSleep.id, endedAt: new Date().toISOString() })
    closeLog()
    setFeedback({ message: '这段睡眠已记好。' })
  }
  const saveGrowth = () => {
    const filledMetrics = babyGrowthChartMetrics.filter((metric) => Boolean(growthValues[metric].trim()))
    if (!filledMetrics.length) { setLogError('请至少填写一项测量数值。'); return }
    for (const metric of filledMetrics) {
      const value = Number(growthValues[metric])
      const maximum = metric === 'weight' ? 50 : 150
      if (!Number.isFinite(value) || value <= 0 || value > maximum) {
        setGrowthMetric(metric)
        setLogError(`请检查${babyGrowthMetricLabels[metric]}数值和单位。`)
        return
      }
    }
    if (!growthDate || growthDate > localDateKey()) { setLogError('测量日期不能晚于今天。'); return }
    if (growthDate < state.baby.birthDate) { setLogError('测量日期不能早于宝宝出生日期。'); return }
    const measuredAt = new Date(`${growthDate}T12:00:00`).toISOString()
    const savedAt = Date.now()
    const createdAt = new Date(savedAt).toISOString()
    const records: BabyGrowthRecord[] = filledMetrics.map((metric) => ({
      id: `baby-growth-${savedAt}-${metric}`,
      babyId: state.baby.id,
      metric,
      value: Number(growthValues[metric]),
      unit: metric === 'weight' ? 'kg' : 'cm',
      measuredAt,
      createdAt
    }))
    dispatch({ type: 'addBabyGrowthRecords', records })
    setGrowthChartMetric(filledMetrics.includes(growthMetric) ? growthMetric : filledMetrics[0] ?? 'weight')
    closeLog()
    const metricNames = filledMetrics.map((metric) => babyGrowthMetricLabels[metric]).join('、')
    setFeedback({ message: records.length > 1 ? `${metricNames}已一起保存。` : `${metricNames}已保存。`, undo: { kind: 'growth', ids: records.map((record) => record.id) } })
  }
  const saveDevelopment = () => {
    const selected = babyDevelopmentItems.filter((item) => developmentDraft[item.id])
    if (!selected.length) { setLogError('至少记录一项具体行为，拿不准可以选择“不确定”。'); return }
    if (!developmentDate || developmentDate > localDateKey()) { setLogError('观察日期不能晚于今天。'); return }
    const checkedAt = new Date(`${developmentDate}T12:00:00`).toISOString()
    const updatedAt = new Date().toISOString()
    dispatch({ type: 'setBabyDevelopmentRecords', records: selected.map((item) => ({
      id: `baby-development-${state.baby.id}-${item.id}`,
      babyId: state.baby.id,
      itemId: item.id,
      label: item.label,
      status: developmentDraft[item.id] as BabyDevelopmentStatus,
      checkedAt,
      updatedAt
    })) })
    closeLog()
    setFeedback({ message: '具体行为和观察日期已记下，不会被直接解释为发育结论。' })
  }
  const undoFeedback = () => {
    if (!feedback?.undo) return
    if (feedback.undo.kind === 'feeding') dispatch({ type: 'removeFeedingRecord', id: feedback.undo.id })
    if (feedback.undo.kind === 'diaper') dispatch({ type: 'removeBabyDiaperRecord', id: feedback.undo.id })
    if (feedback.undo.kind === 'sleep') dispatch({ type: 'removeBabySleepRecord', id: feedback.undo.id })
    if (feedback.undo.kind === 'growth') dispatch({ type: 'removeBabyGrowthRecords', ids: feedback.undo.ids })
    setFeedback(undefined)
  }
  const toggleStoolVisibleSign = (sign: BabyStoolVisibleSign) => setStoolVisibleSigns((current) => current.includes(sign) ? current.filter((item) => item !== sign) : [...current, sign])
  const selectBaby = (babyId: string) => {
    dispatch({ type: 'selectBaby', babyId })
    setBabySwitcherOpen(false)
    setKnowledgeOpen(false)
    setLogMode(undefined)
    setFeedback(undefined)
    setGrowthChartMetric('weight')
  }
  const openBabyProfile = () => {
    setProfileName(state.baby.name)
    setProfileBirthDate(state.baby.birthDate)
    setProfileSex(state.baby.sex)
    setProfileError('')
    setBabySwitcherOpen(false)
    setBabyProfileOpen(true)
  }
  const saveBabyProfile = () => {
    if (!profileName.trim()) { setProfileError('请填写宝宝称呼。'); return }
    if (!profileBirthDate || profileBirthDate > localDateKey()) { setProfileError('请选择不晚于今天的出生日期。'); return }
    if (profileSex === 'unspecified') { setProfileError('请选择出生记录性别，才能显示对应的生长参考范围。'); return }
    dispatch({ type: 'updateBabyProfile', profile: { name: profileName.trim(), birthDate: profileBirthDate, sex: profileSex } })
    setBabyProfileOpen(false)
    setFeedback({ message: '宝宝资料已保存，月龄和生长参考范围已更新。' })
  }

  const latestFeeding = todayFeedingRecords[0]
  const todayBottleVolume = todayFeedingRecords.reduce((total, record) => total + (record.amountMl ?? 0), 0)
  const todayNursingMinutes = todayFeedingRecords.reduce((total, record) => total + (record.durationMinutes ?? 0), 0)
  const feedingFacts = [todayBottleVolume ? `瓶喂 ${todayBottleVolume} ml` : '', todayNursingMinutes ? `亲喂 ${todayNursingMinutes} 分` : ''].filter(Boolean).join(' · ')
  const feedingValue = todayFeedingRecords.length ? `${todayFeedingRecords.length} 次` : '未记录'
  const feedingMeta = latestFeeding ? `最近 ${formatBabyClock(latestFeeding.loggedAt)}${feedingFacts ? ` · ${feedingFacts}` : ''}` : '每次喂养记一条'
  const wetDiaperValue = wetDiapers ? `${wetDiapers} 次` : '未记录'
  const dirtyDiaperValue = dirtyDiapers ? `${dirtyDiapers} 次` : '未记录'
  const sleepValue = activeSleep
    ? '正在睡'
    : todaySleepRecords.length
      ? sleepMinutes < 60 ? `累计 ${sleepMinutes} 分` : `累计 ${Math.floor(sleepMinutes / 60)}时${sleepMinutes % 60 ? `${sleepMinutes % 60}分` : ''}`
      : '未记录'
  const sleepMeta = activeSleep
    ? `${formatBabyClock(activeSleep.startedAt)} 开始`
    : todaySleepRecords.length
      ? `${todaySleepRecords.length} 段 · 最长 ${formatBabyDuration(longestSleepMinutes)}`
      : '每段睡眠记一条'
  const growthMetricCards = [
    { metric: 'weight' as const, label: '体重', unit: 'kg', latest: latestWeight },
    { metric: 'length' as const, label: '身长', unit: 'cm', latest: latestLength },
    { metric: 'head-circumference' as const, label: '头围', unit: 'cm', latest: latestHeadCircumference }
  ]
  const currentBabyAgeLabel = babyAgeLabel(state.baby.birthDate)
  const currentBabySexLabel = state.baby.sex === 'unspecified' ? '性别待完善' : babySexLabels[state.baby.sex]
  const knowledgeWindowEnd = knowledgeReleasedAt.getTime()
  const knowledgeWindowStart = knowledgeWindowEnd - 24 * 60 * 60 * 1000
  const inKnowledgeWindow = (value: string) => {
    const timestamp = new Date(value).getTime()
    return timestamp > knowledgeWindowStart && timestamp <= knowledgeWindowEnd
  }
  const knowledgeFeedingRecords = babyFeedingRecords.filter((record) => inKnowledgeWindow(record.loggedAt))
  const knowledgeDiaperRecords = babyDiaperRecords.filter((record) => inKnowledgeWindow(record.loggedAt))
  const knowledgeSleepRecords = babySleepRecords.filter((record) => inKnowledgeWindow(record.startedAt))
  const knowledgeGrowthRecords = babyGrowthRecords.filter((record) => inKnowledgeWindow(record.measuredAt))
  const knowledgeDevelopmentRecords = babyDevelopmentRecords.filter((record) => inKnowledgeWindow(record.checkedAt))
  const knowledgeSignals: Array<{ topic: BabyKnowledgeTopic; timestamp: number }> = []
  if (knowledgeFeedingRecords[0]) knowledgeSignals.push({ topic: 'feeding', timestamp: new Date(knowledgeFeedingRecords[0].loggedAt).getTime() })
  if (knowledgeDiaperRecords[0]) knowledgeSignals.push({ topic: 'diaper', timestamp: new Date(knowledgeDiaperRecords[0].loggedAt).getTime() })
  if (knowledgeSleepRecords[0]) knowledgeSignals.push({ topic: 'sleep', timestamp: new Date(knowledgeSleepRecords[0].startedAt).getTime() })
  if (knowledgeGrowthRecords[0]) knowledgeSignals.push({ topic: 'growth', timestamp: new Date(knowledgeGrowthRecords[0].measuredAt).getTime() })
  const latestKnowledgeDevelopment = [...knowledgeDevelopmentRecords].sort((a, b) => new Date(b.checkedAt).getTime() - new Date(a.checkedAt).getTime())[0]
  if (latestKnowledgeDevelopment) knowledgeSignals.push({ topic: 'development', timestamp: new Date(latestKnowledgeDevelopment.checkedAt).getTime() })
  const latestKnowledgeSignal = knowledgeSignals.sort((a, b) => b.timestamp - a.timestamp)[0]
  const fallbackKnowledgeTopics: BabyKnowledgeTopic[] = ['feeding-cues', 'sleep', 'development']
  const fallbackSeed = [...`${state.baby.id}-${localDateKey(knowledgeReleasedAt)}`].reduce((total, character) => total + character.charCodeAt(0), 0)
  const knowledgeTopic = latestKnowledgeSignal?.topic ?? fallbackKnowledgeTopics[fallbackSeed % fallbackKnowledgeTopics.length]
  const dailyKnowledge = babyKnowledgeArticles[knowledgeTopic]
  const knowledgeBasis = latestKnowledgeSignal
    ? knowledgeTopic === 'feeding'
      ? `根据 ${state.baby.name} 最近一天的 ${knowledgeFeedingRecords.length} 次喂养记录`
      : knowledgeTopic === 'diaper'
        ? `根据 ${state.baby.name} 最近一天的 ${knowledgeDiaperRecords.length} 次尿便记录`
        : knowledgeTopic === 'sleep'
          ? `根据 ${state.baby.name} 最近一天的 ${knowledgeSleepRecords.length} 段睡眠记录`
          : knowledgeTopic === 'growth'
            ? `根据 ${state.baby.name} 最近一次${babyGrowthMetricLabels[knowledgeGrowthRecords[0].metric]}记录`
            : `根据 ${state.baby.name} 最近一次发育观察`
    : `${currentBabyAgeLabel}阶段内容`
  const statusLogOpen = logMode === 'sleep' || logMode === 'diaper'
  const statusLogTab = logMode === 'sleep' ? 'sleep' : diaperKind === 'wet' ? 'wet' : 'stool'
  return <div className="page-stack home-page baby-page">
    <div className="greeting-row baby-greeting-row"><div className="baby-name-row"><h1>{state.baby.name}</h1><button className="baby-profile-switch" onClick={() => { setBabySwitcherOpen(true); setFeedback(undefined) }} aria-haspopup="dialog" aria-expanded={babySwitcherOpen} aria-label={`当前宝宝 ${state.baby.name}，${currentBabySexLabel}，切换宝宝`}><Icon name="chevron-down" /></button></div><div className="baby-age-context"><span className={`baby-sex-tag ${state.baby.sex === 'unspecified' ? 'incomplete' : ''}`}>{currentBabySexLabel}</span><span className="home-day-count">{currentBabyAgeLabel}</span></div></div>

    <DailyKnowledgeBanner
      label={`更好地了解 ${state.baby.name}`}
      article={dailyKnowledge}
      basis={knowledgeBasis}
      onOpen={() => { setKnowledgeOpen(true); setFeedback(undefined) }}
    />

    <section className="mom-status-section baby-daily-status" aria-labelledby="baby-status-title">
      <div className="mom-status-heading"><div><h2 id="baby-status-title"><MeSectionIcon />今日状态</h2></div><button className="text-button" onClick={() => openLog('sleep')}>记录</button></div>
      <div className="mom-status-grid baby-status-grid">
        <button className="mom-status-item baby-sleep" onClick={() => openLog('sleep')} aria-label={`今日睡眠，${sleepValue}，${sleepMeta}`}>
          <span className="mom-status-icon"><Icon name="moon" /></span>
          <span className="mom-status-label">睡眠</span>
          <strong>{sleepValue.startsWith('累计') ? <><span className="baby-status-value-context">累计</span>{sleepValue.slice(2)}</> : sleepValue}</strong>
        </button>
        <button className="mom-status-item baby-diaper" onClick={() => openLog('diaper', 'wet')} aria-label={`今日尿湿，${wetDiaperValue}，每次更换记一条`}>
          <span className="mom-status-icon"><Icon name="drop" /></span>
          <span className="mom-status-label">尿湿</span>
          <strong>{wetDiaperValue}</strong>
        </button>
        <button className="mom-status-item baby-stool" onClick={() => openLog('diaper', 'dirty')} aria-label={`今日便便，${dirtyDiaperValue}，看到便便时记录`}>
          <span className="mom-status-icon"><Icon name="note" /></span>
          <span className="mom-status-label">便便</span>
          <strong>{dirtyDiaperValue}</strong>
        </button>
      </div>
    </section>

    <section className="lactation-home-section baby-feeding-section" aria-labelledby="baby-feeding-title">
      <div className="lactation-home-heading"><div><h2 id="baby-feeding-title"><Icon name="drop" />今日吃奶</h2></div><button className="text-button" onClick={() => openLog('feeding')}>记录</button></div>
      <button className="lactation-home-summary baby-feeding-summary" onClick={() => openLog('feeding')} aria-label={`记录今日吃奶，${feedingValue}，${feedingMeta}`}>
        <span className="lactation-home-icon"><Icon name="baby" /></span>
        <span className="lactation-home-summary-copy"><strong>{feedingValue}</strong><span>{feedingMeta}</span></span>
        <Icon name="arrow" />
      </button>
    </section>

    <section className="lactation-home-section baby-growth-section" aria-labelledby="baby-growth-title">
      <div className="lactation-home-heading"><div><h2 id="baby-growth-title"><Icon name="note" />生长发育记录</h2></div><button className="text-button" onClick={() => openGrowthLog()}>记录</button></div>
      <div className="baby-growth-metrics" aria-label="生长指标">
        {growthMetricCards.map(({ metric, label, unit, latest }) => {
          const status = latest ? `${latest.value} ${unit}，${formatBabyDate(latest.measuredAt)}` : '未记录'
          return <div key={metric} className="baby-growth-metric" aria-label={`${label}，${status}`}>
            <span className="baby-growth-metric-label">{label}</span>
            {latest ? <><span className="baby-growth-metric-value"><strong>{latest.value}</strong><em>{unit}</em></span><small>{formatBabyDate(latest.measuredAt)}</small></> : <strong className="baby-growth-metric-empty">未记录</strong>}
          </div>
        })}
      </div>
      <BabyGrowthCurve
        metric={growthChartMetric}
        records={growthChartMetric === 'weight' ? weightRecords : growthChartMetric === 'length' ? lengthRecords : headCircumferenceRecords}
        babyName={state.baby.name}
        birthDate={state.baby.birthDate}
        sex={state.baby.sex}
        onMetricChange={setGrowthChartMetric}
        onEditProfile={openBabyProfile}
      />
    </section>

    <section className="lactation-home-section baby-sleep-monitor-section" aria-labelledby="baby-sleep-monitor-title">
      <div className="lactation-home-heading"><div><h2 id="baby-sleep-monitor-title"><Icon name="moon" />睡眠监测</h2><Badge>即将开放</Badge></div></div>
      <div className="baby-sleep-monitor-card" aria-label="睡眠监测，即将开放">
        <div className="baby-sleep-monitor-visual" aria-hidden="true"><img src={babyMonitorPreview} alt="" /></div>
        <div className="baby-sleep-monitor-copy">
          <span className="lactation-home-icon"><Icon name="moon" /></span>
          <span><strong>睡眠节奏与趋势</strong><small>基于连续睡眠记录整理</small></span>
        </div>
      </div>
    </section>

    {feedback && <div className="baby-save-feedback inline-success" role="status"><Icon name="check" /><span>{feedback.message}</span>{feedback.undo && <button className="text-button" onClick={undoFeedback}>撤销</button>}<button className="baby-feedback-close" aria-label="关闭提示" onClick={() => setFeedback(undefined)}>×</button></div>}

    {knowledgeOpen && <DailyKnowledgeModal
      title={`更好地了解 ${state.baby.name}`}
      article={dailyKnowledge}
      boundary="内容用于帮助理解记录，不是对宝宝健康或发育状态的判断。"
      onClose={() => setKnowledgeOpen(false)}
      onAsk={() => { setKnowledgeOpen(false); navigate('/app/agent') }}
    />}

    {babySwitcherOpen && <Modal title="切换宝宝" closeIcon onClose={() => setBabySwitcherOpen(false)} className="baby-switcher-modal"><div className="baby-switcher-body">
      <div className="baby-switch-list" role="radiogroup" aria-label="选择要查看的宝宝">{state.babies.map((baby) => {
        const selected = baby.id === state.activeBabyId
        return <button key={baby.id} className={`baby-switch-option ${selected ? 'selected' : ''}`} role="radio" aria-checked={selected} onClick={() => selectBaby(baby.id)}>
          <span className="baby-avatar" aria-hidden="true">{baby.avatar}</span>
          <span className="baby-switch-copy"><span><strong>{baby.name}</strong>{selected && <Badge tone="green">当前</Badge>}</span></span>
          <span className="baby-switch-check" aria-hidden="true">{selected && <Icon name="check" />}</span>
        </button>
      })}</div>
      <div className="baby-switch-footer"><p className="baby-switch-scope"><Icon name="shield" /> 每个宝宝的喂养、睡眠、尿便和生长发育数据会分开保存。</p><button className="text-button" type="button" onClick={openBabyProfile}>编辑当前宝宝资料</button></div>
    </div></Modal>}

    {babyProfileOpen && <Modal title={`${state.baby.name} 的资料`} closeIcon onClose={() => setBabyProfileOpen(false)} className="baby-profile-modal"><form className="baby-log-form" onSubmit={(event) => { event.preventDefault(); saveBabyProfile() }}>
      <label className="baby-log-field"><span>宝宝称呼</span><input autoFocus maxLength={30} value={profileName} onChange={(event) => { setProfileName(event.target.value); setProfileError('') }} /></label>
      <label className="baby-log-field"><span>出生日期</span><input type="date" max={localDateKey()} value={profileBirthDate} onChange={(event) => { setProfileBirthDate(event.target.value); setProfileError('') }} /></label>
      <fieldset><legend>出生记录性别 <em>用于匹配生长参考范围</em></legend><div className="baby-choice-grid two">
        {([['female', '女宝宝'], ['male', '男宝宝']] as const).map(([value, label]) => <button key={value} type="button" aria-pressed={profileSex === value} className={profileSex === value ? 'selected' : ''} onClick={() => { setProfileSex(value); setProfileError('') }}>{label}</button>)}
      </div></fieldset>
      <p className="baby-log-trust"><Icon name="shield" /> 月龄由出生日期自动计算；出生记录性别仅用于选择对应的生长参考范围。</p>
      {profileError && <div className="mom-editor-error" role="alert">{profileError}</div>}
      <Button type="submit" size="lg">保存宝宝资料</Button>
    </form></Modal>}

    {logMode && <Modal title={statusLogOpen ? '记录今日状态' : logMode === 'growth' ? '生长发育记录' : `记录${babyLogLabels[logMode]}`} closeIcon onClose={closeLog} className={`baby-log-modal${statusLogOpen ? ' baby-status-log-modal' : ''}`}><div className="baby-log-editor">
      {statusLogOpen && <div className="baby-log-tabs baby-status-log-tabs" role="tablist" aria-label="今日状态记录类型">
        <button id="baby-status-log-tab-sleep" role="tab" aria-controls="baby-status-log-panel" aria-selected={statusLogTab === 'sleep'} className={statusLogTab === 'sleep' ? 'active' : ''} onClick={() => switchStatusLog('sleep')}>睡眠</button>
        <button id="baby-status-log-tab-wet" role="tab" aria-controls="baby-status-log-panel" aria-selected={statusLogTab === 'wet'} className={statusLogTab === 'wet' ? 'active' : ''} onClick={() => switchStatusLog('wet')}>尿湿</button>
        <button id="baby-status-log-tab-stool" role="tab" aria-controls="baby-status-log-panel" aria-selected={statusLogTab === 'stool'} className={statusLogTab === 'stool' ? 'active' : ''} onClick={() => switchStatusLog('stool')}>便便</button>
      </div>}
      <div id={statusLogOpen ? 'baby-status-log-panel' : undefined} className="baby-log-panel" role={statusLogOpen ? 'tabpanel' : undefined} aria-labelledby={statusLogOpen ? `baby-status-log-tab-${statusLogTab}` : undefined}>
        {logMode === 'feeding' && <div className="baby-log-form">
          <fieldset><legend>喂养方式</legend><div className="baby-choice-grid three">{(['亲喂', '瓶喂', '配方奶'] as BabyFeedingType[]).map((value) => <button key={value} type="button" aria-pressed={feedingType === value} className={feedingType === value ? 'selected' : ''} onClick={() => { setFeedingType(value); if (value !== '亲喂') setFeedingSide(''); setLogError('') }}>{value}</button>)}</div></fieldset>
          <label className="baby-log-field"><span>发生时间</span><input type="time" value={eventTime} onChange={(event) => { setEventTime(event.target.value); setLogError('') }} /></label>
          {feedingType === '亲喂' && <fieldset><legend>亲喂侧别</legend><div className="baby-choice-grid three">{([['left', '左侧'], ['right', '右侧'], ['both', '两侧']] as const).map(([value, label]) => <button key={value} type="button" aria-pressed={feedingSide === value} className={feedingSide === value ? 'selected' : ''} onClick={() => { setFeedingSide(value); setLogError('') }}>{label}</button>)}</div></fieldset>}
          {feedingType === '亲喂' && <label className="baby-log-field"><span>亲喂时长 <em>未计时可不填</em></span><div className="unit-input"><input aria-label="亲喂时长" type="number" min="1" max="240" inputMode="numeric" value={feedingDuration} onChange={(event) => setFeedingDuration(event.target.value)} placeholder="—" /><em>分钟</em></div></label>}
          {(feedingType === '瓶喂' || feedingType === '配方奶') && <label className="baby-log-field"><span>实际瓶喂量 <em>不知道可不填</em></span><div className="unit-input"><input aria-label="实际瓶喂量" type="number" min="1" max="1000" inputMode="decimal" value={feedingAmount} onChange={(event) => setFeedingAmount(event.target.value)} placeholder="—" /><em>ml</em></div></label>}
          <details className="baby-note-optional"><summary>补充备注 <span>{feedingNote ? '已填写' : '可选，不参与统计'}</span></summary><label className="baby-log-field"><span>只写具体发生的事</span><textarea value={feedingNote} onChange={(event) => setFeedingNote(event.target.value)} placeholder="例如：中途咳嗽 1 次" /></label></details>
          <p className="baby-log-trust"><Icon name="shield" /> 系统统计次数、时长和已填写奶量；亲喂时长不会换算成摄入量。</p>
          {logError && <div className="mom-editor-error" role="alert">{logError}</div>}<Button size="lg" onClick={saveFeeding}>保存这次喂养</Button>
        </div>}
        {logMode === 'diaper' && <div className="baby-log-form">
          <fieldset><legend>这次换到什么</legend><div className="baby-choice-grid three">{([['wet', '尿湿'], ['dirty', '便便'], ['both', '尿湿和便便']] as const).map(([value, label]) => <button key={value} type="button" aria-pressed={diaperKind === value} className={diaperKind === value ? 'selected' : ''} onClick={() => { setDiaperKind(value); if (value !== 'wet') setStoolDiaperKind(value); setLogError('') }}>{label}</button>)}</div></fieldset>
          <label className="baby-log-field"><span>更换时间</span><input type="time" value={eventTime} onChange={(event) => { setEventTime(event.target.value); setLogError('') }} /></label>
          {(diaperKind === 'dirty' || diaperKind === 'both') && <>
            <fieldset><legend>便便颜色 <em>没看清可选“不确定”</em></legend><div className="baby-stool-color-grid">{(Object.keys(babyStoolColorLabels) as BabyStoolColor[]).map((value) => <button key={value} type="button" aria-pressed={stoolColor === value} className={stoolColor === value ? 'selected' : ''} onClick={() => setStoolColor(value)}><span className={`baby-stool-swatch ${value}`} />{babyStoolColorLabels[value]}</button>)}</div></fieldset>
            <fieldset><legend>便便性状 <em>可选</em></legend><div className="baby-choice-grid two">{(Object.keys(babyStoolConsistencyLabels) as BabyStoolConsistency[]).map((value) => <button key={value} type="button" aria-pressed={stoolConsistency === value} className={stoolConsistency === value ? 'selected' : ''} onClick={() => setStoolConsistency(value)}>{babyStoolConsistencyLabels[value]}</button>)}</div></fieldset>
            <fieldset><legend>清楚看到的情况 <em>没有留意可不选</em></legend><div className="baby-choice-grid two">{([['blood', '看到血迹'], ['mucus', '看到黏液']] as const).map(([value, label]) => <button key={value} type="button" aria-pressed={stoolVisibleSigns.includes(value)} className={stoolVisibleSigns.includes(value) ? 'selected' : ''} onClick={() => toggleStoolVisibleSign(value)}>{label}</button>)}</div></fieldset>
          </>}
          <details className="baby-note-optional"><summary>补充备注 <span>{diaperNote ? '已填写' : '可选，不参与统计'}</span></summary><label className="baby-log-field"><span>只写具体发生的事</span><textarea value={diaperNote} onChange={(event) => setDiaperNote(event.target.value)} placeholder="例如：更换时发现漏出" /></label></details>
        </div>}
        {logMode === 'sleep' && <div className="baby-log-form">
          {activeSleep ? <div className="baby-active-sleep"><span className="baby-status-icon sleep"><Icon name="moon" /></span><h3>{state.baby.name} 正在睡</h3><p>从 {formatBabyClock(activeSleep.startedAt)} 开始，现在约 {formatBabyDuration(Math.max(0, Math.round((Date.now() - new Date(activeSleep.startedAt).getTime()) / 60000)))}。</p></div> : <>
            <div className="baby-log-intro"><h3>记录一段明确的起止时间</h3><p>正在睡可以只填入睡时间；已经醒来时，再补上醒来时间。</p></div>
            <label className="baby-log-field"><span>入睡时间</span><input type="datetime-local" max={localDateTimeValue()} value={sleepStartedAt} onChange={(event) => { setSleepStartedAt(event.target.value); setLogError('') }} /></label>
            <label className="baby-log-field"><span>醒来时间 <em>还在睡可不填</em></span><input type="datetime-local" max={localDateTimeValue()} value={sleepEndedAt} onChange={(event) => { setSleepEndedAt(event.target.value); setLogError('') }} /></label>
            <details className="baby-note-optional"><summary>补充备注 <span>{sleepNote ? '已填写' : '可选，不参与统计'}</span></summary><label className="baby-log-field"><span>只写具体发生的事</span><textarea value={sleepNote} onChange={(event) => setSleepNote(event.target.value)} placeholder="例如：入睡后 20 分钟醒来" /></label></details>
            <p className="baby-log-trust"><Icon name="shield" /> 总时长、睡眠段数和最长连续睡眠由起止时间自动计算。</p>
          </>}
        </div>}
        {logMode === 'growth' && <div className="baby-log-form">
          <fieldset><legend>测量项目 <em>可填写一项或多项</em></legend><div className="baby-choice-grid three">{(Object.keys(babyGrowthMetricLabels) as BabyGrowthMetric[]).map((value) => {
            const draftedValue = growthValues[value].trim()
            const selected = growthMetric === value
            const unit = value === 'weight' ? 'kg' : 'cm'
            return <button key={value} type="button" aria-pressed={selected} aria-label={draftedValue ? `${babyGrowthMetricLabels[value]}，已填写 ${draftedValue} ${unit}` : babyGrowthMetricLabels[value]} className={`${selected ? 'selected' : ''} ${draftedValue ? 'has-value' : ''}`.trim()} onClick={() => { setGrowthMetric(value); setLogError('') }}>{babyGrowthMetricLabels[value]}{draftedValue && !selected ? <span className="baby-choice-filled" aria-hidden="true">✓</span> : null}</button>
          })}</div></fieldset>
          <label className="baby-log-field"><span>{babyGrowthMetricLabels[growthMetric]}数值</span><div className="unit-input"><input aria-label={`${babyGrowthMetricLabels[growthMetric]}数值`} type="number" min="0.1" max={growthMetric === 'weight' ? '50' : '150'} step={growthMetric === 'weight' ? '0.01' : '0.1'} inputMode="decimal" value={growthValues[growthMetric]} onChange={(event) => { const value = event.target.value; setGrowthValues((current) => ({ ...current, [growthMetric]: value })); setLogError('') }} placeholder="—" /><em>{growthMetric === 'weight' ? 'kg' : 'cm'}</em></div></label>
          <label className="baby-log-field"><span>测量日期</span><input type="date" max={localDateKey()} value={growthDate} onChange={(event) => { setGrowthDate(event.target.value); setLogError('') }} /></label>
          <p className="baby-log-trust"><Icon name="shield" /> 系统展示测量变化，不把单次结果直接解释为“正常”或“异常”。</p>
          {logError && <div className="mom-editor-error" role="alert">{logError}</div>}<Button size="lg" onClick={saveGrowth}>保存</Button>
        </div>}
        {logMode === 'development' && <div className="baby-log-form">
          <div className="baby-log-intro"><h3>记录具体看到了什么</h3><p>“尚未观察到”只代表这次没有看到，不等于宝宝不会。</p></div>
          <label className="baby-log-field"><span>观察日期</span><input type="date" max={localDateKey()} value={developmentDate} onChange={(event) => { setDevelopmentDate(event.target.value); setLogError('') }} /></label>
          <div className="baby-development-editor">{babyDevelopmentItems.map((item) => <fieldset key={item.id}><legend>{item.label}</legend><div className="baby-choice-grid three">{(Object.keys(babyDevelopmentStatusLabels) as BabyDevelopmentStatus[]).map((status) => <button key={status} type="button" aria-pressed={developmentDraft[item.id] === status} className={developmentDraft[item.id] === status ? 'selected' : ''} onClick={() => { setDevelopmentDraft((current) => ({ ...current, [item.id]: status })); setLogError('') }}>{babyDevelopmentStatusLabels[status]}</button>)}</div></fieldset>)}</div>
          <p className="baby-log-trust"><Icon name="shield" /> 这是带日期的行为观察，不是发育诊断。</p>
          {logError && <div className="mom-editor-error" role="alert">{logError}</div>}<Button size="lg" onClick={saveDevelopment}>保存发育观察</Button>
        </div>}
      </div>
      {statusLogOpen && <div className="baby-status-log-footer">
        {logError && <div className="mom-editor-error" role="alert">{logError}</div>}
        <Button size="lg" onClick={logMode === 'sleep' ? activeSleep ? endSleep : saveSleep : saveDiaper}>{logMode === 'sleep' ? activeSleep ? '记录醒来时间为现在' : sleepEndedAt ? '保存这段睡眠' : '开始记录这段睡眠' : '保存这次记录'}</Button>
      </div>}
    </div></Modal>}
  </div>
}

function RecordsPage() {
  const { state } = useProduct()
  const navigate = useNavigate()
  const [category, setCategory] = useState<'feeding' | 'sleep' | 'diaper' | 'growth' | 'development'>('feeding')
  const [offline, setOffline] = useState(false)
  const feedingRecords = state.feedingRecords.filter((record) => record.babyId === state.baby.id && record.type !== '泵奶').sort((a, b) => new Date(b.loggedAt).getTime() - new Date(a.loggedAt).getTime())
  const sleepRecords = state.babySleepRecords.filter((record) => record.babyId === state.baby.id).sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime())
  const diaperRecords = state.babyDiaperRecords.filter((record) => record.babyId === state.baby.id).sort((a, b) => new Date(b.loggedAt).getTime() - new Date(a.loggedAt).getTime())
  const growthRecords = state.babyGrowthRecords.filter((record) => record.babyId === state.baby.id).sort((a, b) => new Date(b.measuredAt).getTime() - new Date(a.measuredAt).getTime())
  const developmentRecords = state.babyDevelopmentRecords.filter((record) => record.babyId === state.baby.id).sort((a, b) => new Date(b.checkedAt).getTime() - new Date(a.checkedAt).getTime())
  const recordCounts = { feeding: feedingRecords.length, sleep: sleepRecords.length, diaper: diaperRecords.length, growth: growthRecords.length, development: developmentRecords.length }
  const hasRecords = recordCounts[category] > 0
  const categoryLabels = { feeding: '喂养', sleep: '睡眠', diaper: '尿便', growth: '成长', development: '发育观察' } as const
  const diaperLabels = { wet: '尿湿', dirty: '便便', both: '尿湿和便便' } as const
  const breastSideLabels = { left: '左侧', right: '右侧', both: '两侧' } as const
  const visibleSignLabels = { blood: '看到血迹', mucus: '看到黏液' } as const
  return <div className="page-stack records-page"><PageIntro title={`${state.baby.name} 的记录`} back />
    <div className="record-toolbar"><div className="segmented wide records-category-tabs">{(Object.keys(categoryLabels) as Array<keyof typeof categoryLabels>).map((key) => <button key={key} className={category === key ? 'selected' : ''} onClick={() => setCategory(key)}>{categoryLabels[key]}</button>)}</div><button className={`offline-toggle ${offline ? 'active' : ''}`} onClick={() => setOffline(!offline)}><StatusDot tone={offline ? 'amber' : 'green'} />{offline ? '离线' : '已同步'}</button></div>
    {offline && <div className="inline-warning"><Icon name="clock" /><span>离线，联网后同步</span></div>}
    {hasRecords ? <div className="record-list">
      {category === 'feeding' && feedingRecords.map((record) => <Card key={record.id} className="record-row"><div className="record-type"><Icon name={record.type === '亲喂' ? 'baby' : 'plan'} /></div><div><strong>{record.type}</strong><p>{new Date(record.loggedAt).toLocaleString('zh-CN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</p>{record.breastSide && <span>{breastSideLabels[record.breastSide]}</span>}{(record.amountMl || record.durationMinutes) && <span>{record.amountMl ? `${record.amountMl} ml` : `${record.durationMinutes} 分钟`}</span>}{record.note && <span>备注：{record.note}</span>}</div><Badge tone={offline ? 'amber' : 'green'}>{offline ? '待同步' : '已同步'}</Badge></Card>)}
      {category === 'sleep' && sleepRecords.map((record) => {
        const minutes = Math.max(0, Math.round(((record.endedAt ? new Date(record.endedAt).getTime() : Date.now()) - new Date(record.startedAt).getTime()) / 60000))
        return <Card key={record.id} className="record-row"><div className="record-type"><Icon name="moon" /></div><div><strong>{record.endedAt ? '睡眠' : '正在睡'}</strong><p>{new Date(record.startedAt).toLocaleString('zh-CN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}{record.endedAt ? ` — ${new Date(record.endedAt).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}` : ''}</p><span>{formatBabyDuration(minutes)}</span>{record.note && <span>备注：{record.note}</span>}</div><Badge tone={record.endedAt ? offline ? 'amber' : 'green' : 'blue'}>{record.endedAt ? offline ? '待同步' : '已同步' : '记录中'}</Badge></Card>
      })}
      {category === 'diaper' && diaperRecords.map((record) => {
        const stoolFacts = [record.stoolColor ? babyStoolColorLabels[record.stoolColor] : '', record.stoolConsistency ? babyStoolConsistencyLabels[record.stoolConsistency] : '', ...(record.stoolVisibleSigns ?? []).map((sign) => visibleSignLabels[sign])].filter(Boolean).join(' · ')
        return <Card key={record.id} className="record-row"><div className="record-type"><Icon name={record.kind === 'wet' ? 'drop' : 'note'} /></div><div><strong>{diaperLabels[record.kind]}</strong><p>{new Date(record.loggedAt).toLocaleString('zh-CN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</p>{stoolFacts && <span>{stoolFacts}</span>}{record.note && <span>备注：{record.note}</span>}</div><Badge tone={offline ? 'amber' : 'green'}>{offline ? '待同步' : '已同步'}</Badge></Card>
      })}
      {category === 'growth' && growthRecords.map((record) => <Card key={record.id} className="record-row"><div className="record-type"><Icon name="plan" /></div><div><strong>{babyGrowthMetricLabels[record.metric]} {record.value} {record.unit}</strong><p>{new Date(record.measuredAt).toLocaleDateString('zh-CN', { year: 'numeric', month: 'short', day: 'numeric' })}</p></div><Badge tone={offline ? 'amber' : 'green'}>{offline ? '待同步' : '已同步'}</Badge></Card>)}
      {category === 'development' && developmentRecords.map((record) => <Card key={record.id} className="record-row"><div className="record-type"><Icon name="spark" /></div><div><strong>{record.label}</strong><p>{new Date(record.checkedAt).toLocaleDateString('zh-CN', { year: 'numeric', month: 'short', day: 'numeric' })}</p><span>{babyDevelopmentStatusLabels[record.status]}</span></div><Badge tone={offline ? 'amber' : 'neutral'}>{offline ? '待同步' : '已保存'}</Badge></Card>)}
    </div> : <EmptyState title={`还没有${categoryLabels[category]}记录`} body="目前没有记录，也不会计为 0；可从宝宝页开始。" action={<Button onClick={() => navigate('/app/baby')}>去记录</Button>} />}
    <details className="data-source-disclosure"><summary><Icon name="shield" /><span>数据来源</span><span>{offline ? '本地缓存' : '手动记录'} · 查看隐私</span></summary><button className="text-button" onClick={() => navigate('/app/privacy')}>隐私与授权</button></details>
  </div>
}

function PrivacyPage() {
  const { state, dispatch, consultation } = useProduct()
  const requiredScopes = [
    { key: 'app_service', title: '保存我的记录', description: '用于保存你主动填写的档案、妈妈与宝宝记录。', impact: '关闭后，记录与当前服务无法继续。' },
    { key: 'ibclc_case', title: '提供给本次服务的 IBCLC', description: '仅允许被分配的 IBCLC 查看本次信息采集表和授权记录。', impact: '关闭后，IBCLC 无法再次打开本次表单；已查看或依法保留的记录不会删除。' },
    { key: 'video', title: '进入视频咨询', description: '用于进入已预约的视频房间；默认不录音、不录像。', impact: '关闭后，无法再次进入本次视频咨询。' }
  ] as const
  const optionalScopes = [
    { key: 'ai_context', title: '让 Cozymate 使用已选记录', description: '在你选择的范围内衔接对话上下文。', impact: '关闭后仍可使用通用对话，已有记录不会删除。' },
    { key: 'notifications', title: '接收服务提醒', description: '用于预约、任务、跟进和安全提醒。', impact: '关闭后不再主动提醒，仍可在 App 内查看安排。' }
  ] as const
  const [scopes, setScopes] = useState(state.consent.scopes)
  const [saved, setSaved] = useState(false)
  const [confirming, setConfirming] = useState(false)
  const dirty = scopes.length !== state.consent.scopes.length || scopes.some((scope) => !state.consent.scopes.includes(scope))
  const requiredReady = requiredScopes.every(({ key }) => scopes.includes(key))
  const removedRequiredScopes = requiredScopes.filter(({ key }) => state.consent.scopes.includes(key) && !scopes.includes(key))
  useEffect(() => {
    if (
      consultation.mode !== 'server'
      || !state.appointment?.intakeSubmitted
      || state.appointment.consentActive === undefined
    ) return
    setScopes((current) => {
      const withoutAppointmentScopes = current.filter((scope) => scope !== 'ibclc_case' && scope !== 'video')
      const withAppService = withoutAppointmentScopes.includes('app_service')
        ? withoutAppointmentScopes
        : ['app_service', ...withoutAppointmentScopes]
      return state.appointment?.consentActive
        ? Array.from(new Set([...withAppService, 'ibclc_case', 'video']))
        : withAppService
    })
    setSaved(false)
  }, [consultation.mode, state.appointment?.id, state.appointment?.intakeSubmitted, state.appointment?.consentActive])
  const toggleScope = (key: string) => {
    setSaved(false)
    consultation.clearError()
    setScopes((current) => {
      if (key === 'ibclc_case' || key === 'video') {
        const pairedScopes = ['ibclc_case', 'video']
        return current.includes(key)
          ? current.filter((item) => !pairedScopes.includes(item))
          : Array.from(new Set([...current, ...pairedScopes]))
      }
      return current.includes(key) ? current.filter((item) => item !== key) : [...current, key]
    })
  }
  const save = async () => {
    const appointmentConsentWasActive = state.appointment?.intakeReady
      ?? (state.consent.scopes.includes('ibclc_case') && state.consent.scopes.includes('video'))
    const appointmentConsentWillBeActive = scopes.includes('ibclc_case') && scopes.includes('video')
    if (
      consultation.mode === 'server'
      && state.appointment
      && state.appointment.intakeSubmitted
      && appointmentConsentWasActive !== appointmentConsentWillBeActive
    ) {
      const updated = await consultation.updateIntakeConsent(
        state.appointment.id,
        appointmentConsentWillBeActive,
        state.consent.version,
      )
      if (!updated) {
        setConfirming(false)
        return
      }
    }
    dispatch({ type: 'setConsent', status: requiredReady ? 'active' : 'revoked', scopes })
    setSaved(true)
    setConfirming(false)
  }
  const requestSave = () => removedRequiredScopes.length ? setConfirming(true) : void save()
  const renderScope = ({ key, title, description, impact }: (typeof requiredScopes)[number] | (typeof optionalScopes)[number], required: boolean) => {
    const enabled = scopes.includes(key)
    const descriptionId = `scope-${key}-description`
    const impactId = `scope-${key}-impact`
    return <label className={`privacy-scope-row ${required ? 'required' : 'optional'}`} key={key}>
      <span className="privacy-scope-copy"><strong>{title}</strong><span id={descriptionId}>{description}</span><small id={impactId}>{impact}</small></span>
      <span className="privacy-scope-control"><input id={`scope-${key}`} type="checkbox" role="switch" aria-describedby={`${descriptionId} ${impactId}`} checked={enabled} onChange={() => toggleScope(key)} /><span className="privacy-switch" aria-hidden="true" /><span>{enabled ? '已开启' : '已关闭'}</span></span>
    </label>
  }
  return <div className="page-stack privacy-page">
    <PageIntro title="隐私与数据" body="按用途决定谁可以使用哪些信息。" back />
    <section className="privacy-scope-section" aria-labelledby="required-scope-title">
      <div className="privacy-section-heading"><h2 id="required-scope-title">服务所需</h2><p>用于保存记录、接受专家支持和进入视频咨询。本次表单共享与视频入场授权会同步开启或关闭，不会自动删除历史记录。</p></div>
      <div className="privacy-scope-list">{requiredScopes.map((scope) => renderScope(scope, true))}</div>
    </section>
    <section className="privacy-scope-section" aria-labelledby="optional-scope-title">
      <div className="privacy-section-heading"><h2 id="optional-scope-title">按需开启</h2><p>不影响 App 的基础记录，可以随时调整。</p></div>
      <div className="privacy-scope-list">{optionalScopes.map((scope) => renderScope(scope, false))}</div>
    </section>
    {saved && <div className="inline-success" role="status"><Icon name="check" /><span>隐私设置已保存</span></div>}
    {consultation.error && <div className="inline-error" role="alert">{consultation.error}</div>}
    {dirty && <div className="privacy-save"><Button size="lg" disabled={consultation.busy} onClick={requestSave}>{consultation.busy ? '正在保存…' : '保存更改'}</Button></div>}
    {confirming && <Modal title="确认关闭服务授权？" className="privacy-confirm-modal" onClose={() => { if (!consultation.busy) setConfirming(false) }}><div className="privacy-confirm-content"><p>关闭后，将立即停止后续表单查看或视频入场。已经查看或依法需要保留的服务记录不会被删除。</p><ul>{removedRequiredScopes.map(({ key, title }) => <li key={key}>{title}</li>)}</ul><div className="privacy-confirm-actions"><Button size="lg" variant="ghost" disabled={consultation.busy} onClick={() => setConfirming(false)}>继续保留</Button><Button size="lg" variant="danger" disabled={consultation.busy} onClick={() => { void save() }}>{consultation.busy ? '正在关闭…' : '确认关闭'}</Button></div></div></Modal>}
  </div>
}

function getAgentConversationTitle(messages: AgentMessage[]) {
  const firstUserMessage = messages.find((message) => message.role === 'user')
  const firstPrompt = firstUserMessage?.text.replace(/\s+/g, ' ').trim()
    || firstUserMessage?.attachments?.[0]?.name
  if (!firstPrompt) return '与 Cozymate 的对话'
  return firstPrompt.length > 26 ? `${firstPrompt.slice(0, 26)}…` : firstPrompt
}

function formatAgentConversationTime(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '较早'
  return new Intl.DateTimeFormat('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(date)
}

function isAgentRunActive(run: AgentRunState) {
  return run.phase === 'preparing' || run.phase === 'streaming' || run.phase === 'cancelRequested'
}

function safeAgentHref(value: string) {
  return /^https?:\/\//i.test(value) ? value : undefined
}

function renderAgentInline(value: string, keyPrefix: string): ReactNode[] {
  return value.split(/(\*\*[^*]+\*\*|\[[^\]]+\]\(https?:\/\/[^)\s]+\))/g).filter(Boolean).map((token, index) => {
    const strongMatch = token.match(/^\*\*([^*]+)\*\*$/)
    if (strongMatch) return <strong key={`${keyPrefix}-strong-${index}`}>{strongMatch[1]}</strong>
    const linkMatch = token.match(/^\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)$/)
    if (linkMatch) return <a key={`${keyPrefix}-link-${index}`} href={linkMatch[2]} target="_blank" rel="noreferrer">{linkMatch[1]}</a>
    return token
  })
}

function AgentMarkdownText({ text }: { text: string }) {
  const content = text.trim()
  if (!content) return null
  return <div className="agent-markdown">{content.split(/\n{2,}/).map((block, blockIndex) => {
    const lines = block.split('\n')
    const imageMatch = block.match(/^!\[([^\]]*)\]\((https?:\/\/[^)\s]+)\)$/)
    if (imageMatch) return <figure key={`image-${blockIndex}`}><img src={imageMatch[2]} alt={imageMatch[1]} loading="lazy" referrerPolicy="no-referrer" />{imageMatch[1] && <figcaption>{imageMatch[1]}</figcaption>}</figure>
    if (lines.every((line) => /^[-*]\s+/.test(line))) return <ul key={`list-${blockIndex}`}>{lines.map((line, lineIndex) => <li key={lineIndex}>{renderAgentInline(line.replace(/^[-*]\s+/, ''), `ul-${blockIndex}-${lineIndex}`)}</li>)}</ul>
    if (lines.every((line) => /^\d+[.)]\s+/.test(line))) return <ol key={`list-${blockIndex}`}>{lines.map((line, lineIndex) => <li key={lineIndex}>{renderAgentInline(line.replace(/^\d+[.)]\s+/, ''), `ol-${blockIndex}-${lineIndex}`)}</li>)}</ol>
    const headingMatch = block.match(/^#{1,3}\s+(.+)$/)
    if (headingMatch) return <h3 key={`heading-${blockIndex}`}>{renderAgentInline(headingMatch[1], `heading-${blockIndex}`)}</h3>
    return <p key={`paragraph-${blockIndex}`}>{lines.map((line, lineIndex) => <span key={lineIndex}>{renderAgentInline(line, `p-${blockIndex}-${lineIndex}`)}{lineIndex < lines.length - 1 && <br />}</span>)}</p>
  })}</div>
}

function AgentCitations({ message }: { message: AgentMessage }) {
  const citations = message.citations?.filter((citation) => safeAgentHref(citation.url)) ?? []
  if (!citations.length) return null
  return <section className="agent-citations" aria-label="参考来源"><strong>参考来源</strong><ol>{citations.map((citation, index) => <li key={citation.id || `${citation.url}-${index}`}><a href={citation.url} target="_blank" rel="noreferrer"><span>{index + 1}</span><span>{citation.title}</span></a>{citation.source && <small>{citation.source}</small>}</li>)}</ol></section>
}

interface PendingAgentAttachment extends AgentAttachmentPayload {
  previewUrl?: string
}

function createAgentAttachmentId() {
  const token = typeof globalThis.crypto?.randomUUID === 'function'
    ? globalThis.crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`
  return `attachment-${token}`
}

function readAgentFileAsDataUrl(file: File, mimeType: string) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onerror = () => reject(new Error(`无法读取 ${file.name || '附件'}。`))
    reader.onabort = () => reject(new Error(`已停止读取 ${file.name || '附件'}。`))
    reader.onload = () => {
      const result = typeof reader.result === 'string' ? reader.result : ''
      const separator = result.indexOf(',')
      if (separator < 0) {
        reject(new Error(`无法读取 ${file.name || '附件'}。`))
        return
      }
      resolve(`data:${mimeType};base64,${result.slice(separator + 1)}`)
    }
    reader.readAsDataURL(file)
  })
}

function attachmentMessageMetadata(attachment: PendingAgentAttachment): AgentMessageAttachment {
  return {
    id: attachment.id,
    kind: attachment.kind,
    name: attachment.name,
    mimeType: attachment.mimeType,
    size: attachment.size,
  }
}

function sameMessageAttachments(
  messageAttachments: AgentMessageAttachment[] | undefined,
  pendingAttachments: PendingAgentAttachment[],
) {
  if ((messageAttachments?.length ?? 0) !== pendingAttachments.length) return false
  return pendingAttachments.every((attachment, index) => {
    const saved = messageAttachments?.[index]
    return saved?.id === attachment.id
      && saved.kind === attachment.kind
      && saved.name === attachment.name
      && saved.mimeType === attachment.mimeType
      && saved.size === attachment.size
  })
}

function AgentMessageAttachments({ attachments }: { attachments?: AgentMessageAttachment[] }) {
  if (!attachments?.length) return null
  return <div className="agent-message-attachments">{attachments.map((attachment) => <span key={attachment.id} className="agent-message-attachment"><Icon name={attachment.kind === 'image' ? 'image' : 'file'} /><span><strong>{attachment.name}</strong><small>{formatAgentAttachmentSize(attachment.size)}</small></span></span>)}</div>
}

const agentQuickActions = [
  { id: 'milk-supply', label: '奶量分析', prompt: '帮我分析最近的奶量记录，告诉我可以先关注哪些变化。' },
  { id: 'postpartum-recovery', label: '产后康复评估', prompt: '我想做一次产后身体恢复评估，请先从最重要的问题开始问我。' },
] as const

interface AgentSendOptions {
  consultationAppointmentId?: string
  hiddenUserMessage?: boolean
  contextPackageId?: string
}

function AgentPage({ isActive = true }: { isActive?: boolean }) {
  const { state, dispatch, consultation } = useProduct()
  const location = useLocation()
  const messages = useMemo(() => normalizeAgentMessages(state.agentMessages), [state.agentMessages])
  const [agentRun, setAgentRun] = useState<AgentRunState>(() => recoverInterruptedAgentRun(messages))
  const [showEarlier, setShowEarlier] = useState(false)
  const [showLatest, setShowLatest] = useState(false)
  const [historyOpen, setHistoryOpen] = useState(false)
  const [attachmentOpen, setAttachmentOpen] = useState(false)
  const [capabilityNotice, setCapabilityNotice] = useState('')
  const [voiceEnabled, setVoiceEnabled] = useState(readAgentVoicePreference)
  const [pendingAttachments, setPendingAttachmentsState] = useState<PendingAgentAttachment[]>([])
  const [attachmentsPreparing, setAttachmentsPreparing] = useState(false)
  const activeRun = useRef<string | undefined>(undefined)
  const activeRequest = useRef<AbortController | undefined>(undefined)
  const activeTurnAttachments = useRef<PendingAgentAttachment[]>([])
  const activeConversation = useRef(state.agentConversationId)
  const pendingAgentText = useRef<{ runId: string; prompt: string; messageId: string; text: string } | undefined>(undefined)
  const agentTextFrame = useRef<{ animation: number; fallback: number } | undefined>(undefined)
  const agentTextFrameWaiters = useRef<Array<() => void>>([])
  const followLatest = useRef(true)
  const threadRef = useRef<HTMLDivElement>(null)
  const composerRef = useRef<HTMLTextAreaElement>(null)
  const historyPanelRef = useRef<HTMLElement>(null)
  const historyTriggerRef = useRef<HTMLButtonElement>(null)
  const historySwipeStart = useRef<{ x: number; y: number; at: number } | undefined>(undefined)
  const preconsultRequest = useRef<string | undefined>(undefined)
  const postconsultRequest = useRef<string | undefined>(undefined)
  const postconsultReferences = useRef<Record<string, string>>({})
  const currentPostconsultKey = postconsultStorageKey(state.user.id, state.agentConversationId)
  const readPostconsultReference = () => {
    try { return postconsultReferences.current[currentPostconsultKey] || sessionStorage.getItem(currentPostconsultKey) || undefined } catch { return postconsultReferences.current[currentPostconsultKey] }
  }
  const attachmentControlRef = useRef<HTMLDivElement>(null)
  const attachmentMenuRef = useRef<HTMLDivElement>(null)
  const attachmentTriggerRef = useRef<HTMLButtonElement>(null)
  const cameraInputRef = useRef<HTMLInputElement>(null)
  const photoInputRef = useRef<HTMLInputElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const pendingAttachmentsRef = useRef<PendingAgentAttachment[]>([])
  const attachmentSelectionVersion = useRef(0)
  const voiceCoordinator = useRef(new AgentVoicePlaybackCoordinator())
  const voiceSession = useRef<AgentVoicePlaybackSession | undefined>(undefined)
  const voiceRunId = useRef<string | undefined>(undefined)
  const voiceText = useRef('')
  const [voicePhase, setVoicePhase] = useState<'idle' | 'connecting' | 'playing'>('idle')
  const [voiceError, setVoiceError] = useState('')
  const navigate = useNavigate()
  const isRunning = isAgentRunActive(agentRun)
  const composerBusy = isRunning || attachmentsPreparing

  const updatePendingAttachments = (
    value: PendingAgentAttachment[] | ((current: PendingAgentAttachment[]) => PendingAgentAttachment[]),
  ) => {
    setPendingAttachmentsState((current) => {
      const next = typeof value === 'function' ? value(current) : value
      pendingAttachmentsRef.current = next
      return next
    })
  }

  const releaseAttachmentPreviews = (attachments: PendingAgentAttachment[]) => {
    const previewUrls = new Set(attachments.flatMap((attachment) => attachment.previewUrl ? [attachment.previewUrl] : []))
    previewUrls.forEach((previewUrl) => URL.revokeObjectURL(previewUrl))
  }

  const discardPendingAttachments = () => {
    attachmentSelectionVersion.current += 1
    setAttachmentsPreparing(false)
    const discarded = pendingAttachmentsRef.current
    pendingAttachmentsRef.current = []
    setPendingAttachmentsState([])
    releaseAttachmentPreviews(discarded)
  }

  const restoreActiveTurnAttachments = () => {
    const attachments = activeTurnAttachments.current
    activeTurnAttachments.current = []
    if (!attachments.length) return
    updatePendingAttachments((current) => current.length ? current : attachments)
  }

  const cancelVoicePlayback = (updateState = true) => {
    const session = voiceSession.current
    voiceSession.current = undefined
    voiceRunId.current = undefined
    voiceText.current = ''
    if (updateState) setVoicePhase('idle')
    void voiceCoordinator.current.cancel()
    if (session) void session.cancel().catch(() => { /* best-effort audio teardown */ })
  }

  const beginVoicePlayback = (runId: string) => {
    if (!voiceEnabled) return
    cancelVoicePlayback()
    setVoiceError('')
    setVoicePhase('connecting')
    const session = createAgentVoicePlaybackSession({
      getAccessToken: consultation.mode === 'server' ? () => consultation.accessToken('user') : undefined,
      allowBrowserFallback: consultation.mode !== 'server',
      onPlaying: () => { if (voiceRunId.current === runId) setVoicePhase('playing') },
      onError: (message) => { if (voiceRunId.current === runId) setVoiceError(message) },
    })
    voiceSession.current = session
    voiceRunId.current = runId
    voiceText.current = ''
    voiceCoordinator.current.request(runId, () => session.cancel())
    void session.done.then(() => {
      if (voiceSession.current !== session) return
      voiceSession.current = undefined
      voiceRunId.current = undefined
      voiceText.current = ''
      voiceCoordinator.current.finish(runId)
      setVoicePhase('idle')
    })
  }

  const appendVoiceText = (runId: string, cumulativeText: string) => {
    const session = voiceSession.current
    if (!session || voiceRunId.current !== runId || !cumulativeText) return
    const previousText = voiceText.current
    const delta = cumulativeText.startsWith(previousText)
      ? cumulativeText.slice(previousText.length)
      : cumulativeText
    voiceText.current = cumulativeText
    if (delta) session.append(delta)
  }

  const finishVoicePlayback = (runId: string) => {
    if (voiceRunId.current !== runId) return
    voiceSession.current?.finish()
  }

  const toggleVoicePlayback = () => {
    if (voiceEnabled) cancelVoicePlayback()
    setVoiceError('')
    setVoiceEnabled((current) => !current)
  }

  const replayVoice = () => {
    const reply = [...messages].reverse().find((message) => message.role === 'assistant' && message.text.trim())
    if (!reply || composerBusy) return
    const runId = `replay-${Date.now()}`
    beginVoicePlayback(runId)
    appendVoiceText(runId, reply.text)
    finishVoicePlayback(runId)
  }

  const liveAssistantMessage: AgentMessage | undefined = agentRun.phase !== 'idle' && agentRun.messageId
    ? { id: agentRun.messageId, role: 'assistant' as const, text: agentRun.partialText, createdAt: new Date().toISOString() }
    : undefined
  const transcriptMessages = liveAssistantMessage ? [...messages, liveAssistantMessage] : messages
  const visibleMessages = showEarlier ? transcriptMessages : transcriptMessages.slice(-8)
  const hiddenCount = Math.max(0, transcriptMessages.length - visibleMessages.length)
  const hasCurrentConversation = messages.some((message) => message.role === 'user') || state.agentDraft.trim().length > 0
  const currentConversation = useMemo<AgentConversation>(() => ({
    id: state.agentConversationId,
    title: getAgentConversationTitle(messages),
    updatedAt: messages[messages.length - 1]?.createdAt ?? new Date().toISOString(),
    messages,
    finalResponseId: state.finalResponseId,
    draft: state.agentDraft
  }), [messages, state.agentConversationId, state.finalResponseId, state.agentDraft])
  const conversationItems = useMemo(() => {
    const archived = state.agentHistory.filter((conversation) => conversation.id !== state.agentConversationId)
    return hasCurrentConversation ? [currentConversation, ...archived] : archived
  }, [currentConversation, hasCurrentConversation, state.agentConversationId, state.agentHistory])

  const flushPendingAgentText = () => {
    const frame = agentTextFrame.current
    if (frame) {
      window.cancelAnimationFrame(frame.animation)
      window.clearTimeout(frame.fallback)
      agentTextFrame.current = undefined
    }
    const pending = pendingAgentText.current
    pendingAgentText.current = undefined
    if (pending && activeRun.current === pending.runId) {
      setAgentRun((current) => current.messageId === pending.messageId
        ? { ...current, phase: 'streaming', prompt: pending.prompt, partialText: pending.text, status: '' }
        : current)
    }
    const waiters = agentTextFrameWaiters.current.splice(0)
    waiters.forEach((resolve) => resolve())
  }

  const cancelPendingAgentText = () => {
    const frame = agentTextFrame.current
    if (frame) {
      window.cancelAnimationFrame(frame.animation)
      window.clearTimeout(frame.fallback)
      agentTextFrame.current = undefined
    }
    pendingAgentText.current = undefined
    const waiters = agentTextFrameWaiters.current.splice(0)
    waiters.forEach((resolve) => resolve())
  }

  const queueAgentText = (runId: string, prompt: string, messageId: string, text: string) => {
    pendingAgentText.current = { runId, prompt, messageId, text }
    if (agentTextFrame.current) return
    const animation = window.requestAnimationFrame(flushPendingAgentText)
    const fallback = window.setTimeout(flushPendingAgentText, 48)
    agentTextFrame.current = { animation, fallback }
  }

  const waitForAgentTextPaint = (runId: string, prompt: string, messageId: string, text: string) => new Promise<void>((resolve) => {
    agentTextFrameWaiters.current.push(() => {
      let settled = false
      const finish = () => {
        if (settled) return
        settled = true
        window.cancelAnimationFrame(animation)
        window.clearTimeout(fallback)
        resolve()
      }
      const animation = window.requestAnimationFrame(finish)
      const fallback = window.setTimeout(finish, 48)
    })
    queueAgentText(runId, prompt, messageId, text)
  })

  const resizeComposer = () => {
    const textarea = composerRef.current
    if (!textarea) return
    textarea.style.height = 'auto'
    textarea.style.height = `${Math.min(textarea.scrollHeight, 112)}px`
  }

  const scrollToLatest = (behavior: ScrollBehavior = 'smooth') => {
    const thread = threadRef.current
    if (!thread) return
    followLatest.current = true
    setShowLatest(false)
    thread.scrollTo({ top: thread.scrollHeight, behavior })
    if (behavior === 'auto') {
      window.requestAnimationFrame(() => {
        const isNearLatest = thread.scrollHeight - thread.scrollTop - thread.clientHeight < 72
        followLatest.current = isNearLatest
        setShowLatest(!isNearLatest)
      })
    }
  }

  useEffect(() => { resizeComposer() }, [state.agentDraft])
  useEffect(() => {
    try {
      window.localStorage.setItem(AGENT_VOICE_PREFERENCE_KEY, String(voiceEnabled))
    } catch {
      // Voice preference is best-effort when storage is unavailable.
    }
  }, [voiceEnabled])
  useEffect(() => {
    if (!followLatest.current) return
    window.requestAnimationFrame(() => scrollToLatest('auto'))
  }, [messages.length, agentRun.phase, agentRun.partialText])
  useEffect(() => {
    let cancelled = false
    void document.fonts?.ready.then(() => {
      if (!cancelled && followLatest.current) scrollToLatest('auto')
    })
    return () => { cancelled = true }
  }, [])
  useEffect(() => () => {
    activeRun.current = undefined
    activeRequest.current?.abort()
    cancelVoicePlayback(false)
    cancelPendingAgentText()
    attachmentSelectionVersion.current += 1
    releaseAttachmentPreviews([...pendingAttachmentsRef.current, ...activeTurnAttachments.current])
    pendingAttachmentsRef.current = []
    activeTurnAttachments.current = []
  }, [])
  useEffect(() => {
    if (activeConversation.current === state.agentConversationId) return
    activeConversation.current = state.agentConversationId
    activeRun.current = undefined
    activeRequest.current?.abort()
    activeRequest.current = undefined
    cancelVoicePlayback()
    cancelPendingAgentText()
    discardPendingAttachments()
    setAgentRun(recoverInterruptedAgentRun(messages))
  }, [messages, state.agentConversationId])
  useEffect(() => {
    if (isActive) return
    setHistoryOpen(false)
    setAttachmentOpen(false)
    // AgentPage is kept mounted while the bottom navigation changes route.
    // Stop audio explicitly so a reply cannot continue speaking after the
    // user has left Cozymate, while the text run itself remains resumable.
    cancelVoicePlayback()
  }, [isActive])
  useEffect(() => {
    if (!historyOpen) return
    const previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : historyTriggerRef.current
    const panel = historyPanelRef.current
    const navigation = historyTriggerRef.current?.closest('.user-shell')?.querySelector<HTMLElement>('.bottom-nav')
    const previousNavigationAriaHidden = navigation?.getAttribute('aria-hidden')
    navigation?.setAttribute('inert', '')
    navigation?.setAttribute('aria-hidden', 'true')
    const focusableSelector = 'button:not(:disabled), a[href], input:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])'
    window.requestAnimationFrame(() => panel?.querySelector<HTMLElement>(focusableSelector)?.focus())
    const handleDialogKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault()
        setHistoryOpen(false)
        return
      }
      if (event.key !== 'Tab' || !panel) return
      const focusable = Array.from(panel.querySelectorAll<HTMLElement>(focusableSelector))
      if (!focusable.length) return
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }
    document.addEventListener('keydown', handleDialogKeyDown)
    return () => {
      document.removeEventListener('keydown', handleDialogKeyDown)
      navigation?.removeAttribute('inert')
      if (previousNavigationAriaHidden == null) navigation?.removeAttribute('aria-hidden')
      else navigation?.setAttribute('aria-hidden', previousNavigationAriaHidden)
      previouslyFocused?.focus()
    }
  }, [historyOpen])
  useEffect(() => {
    if (!attachmentOpen) return
    window.requestAnimationFrame(() => attachmentMenuRef.current?.querySelector<HTMLButtonElement>('button')?.focus())
    const handlePointerDown = (event: PointerEvent) => {
      if (event.target instanceof Node && !attachmentControlRef.current?.contains(event.target)) setAttachmentOpen(false)
    }
    const handleAttachmentKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return
      event.preventDefault()
      setAttachmentOpen(false)
      attachmentTriggerRef.current?.focus()
    }
    document.addEventListener('pointerdown', handlePointerDown)
    document.addEventListener('keydown', handleAttachmentKeyDown)
    return () => {
      document.removeEventListener('pointerdown', handlePointerDown)
      document.removeEventListener('keydown', handleAttachmentKeyDown)
    }
  }, [attachmentOpen])

  const handleThreadScroll = () => {
    const thread = threadRef.current
    if (!thread) return
    const isNearLatest = thread.scrollHeight - thread.scrollTop - thread.clientHeight < 72
    followLatest.current = isNearLatest
    setShowLatest(!isNearLatest)
  }

  const revealEarlier = () => {
    const thread = threadRef.current
    const previousHeight = thread?.scrollHeight ?? 0
    followLatest.current = false
    setShowEarlier(true)
    window.requestAnimationFrame(() => {
      if (!thread) return
      thread.scrollTop = thread.scrollHeight - previousHeight
      setShowLatest(true)
    })
  }

  const chooseAttachment = (input: HTMLInputElement | null) => {
    setAttachmentOpen(false)
    setCapabilityNotice('')
    attachmentTriggerRef.current?.focus()
    input?.click()
  }

  const handleAttachmentSelection = async (files: File[], source: AgentAttachmentSource) => {
    if (!files.length || isRunning) return
    const selection = selectAgentAttachmentCandidates(pendingAttachmentsRef.current, files, source)
    const rejectedNotice = selection.rejected.map((item) => item.reason).slice(0, 2).join(' ')
    if (!selection.accepted.length) {
      if (rejectedNotice) setCapabilityNotice(rejectedNotice)
      return
    }
    const selectionVersion = ++attachmentSelectionVersion.current
    setAttachmentsPreparing(true)
    setCapabilityNotice(rejectedNotice)
    const preparedResults = await Promise.all(selection.accepted.map(async ({ candidate: file, ...descriptor }) => {
      try {
        const dataUrl = await readAgentFileAsDataUrl(file, descriptor.mimeType)
        return {
          attachment: {
            ...descriptor,
            id: createAgentAttachmentId(),
            dataUrl,
            previewUrl: descriptor.kind === 'image' ? URL.createObjectURL(file) : undefined,
          } satisfies PendingAgentAttachment,
        }
      } catch (error) {
        return { error: error instanceof Error ? error.message : `无法读取 ${descriptor.name}。` }
      }
    }))
    const prepared = preparedResults.flatMap((result) => result.attachment ? [result.attachment] : [])
    const readErrors = preparedResults.flatMap((result) => result.error ? [result.error] : [])
    if (selectionVersion !== attachmentSelectionVersion.current) {
      releaseAttachmentPreviews(prepared)
      return
    }
    if (prepared.length) updatePendingAttachments((current) => [...current, ...prepared])
    setAttachmentsPreparing(false)
    const notice = [rejectedNotice, ...readErrors].filter(Boolean).join(' ')
    setCapabilityNotice(notice)
  }

  const removePendingAttachment = (id: string) => {
    updatePendingAttachments((current) => {
      const removed = current.find((attachment) => attachment.id === id)
      if (removed) releaseAttachmentPreviews([removed])
      return current.filter((attachment) => attachment.id !== id)
    })
    setCapabilityNotice('')
  }

  const send = (prompt?: string, reuseLastUserMessage = false, options: AgentSendOptions = {}) => {
    const text = (prompt ?? state.agentDraft).trim()
    const turnAttachments = pendingAttachmentsRef.current
    const hiddenUserMessage = Boolean(options.hiddenUserMessage)
    const contextPackageId = options.contextPackageId ?? state.selectedPackageId
    if ((!text && !turnAttachments.length) || composerBusy) return
    if (reuseLastUserMessage && agentRun.requiresAttachmentReselection && !turnAttachments.length) {
      setCapabilityNotice('请先重新选择这次消息需要的附件。')
      return
    }
    followLatest.current = true
    setCapabilityNotice('')
    setAttachmentOpen(false)
    const retryMessage = reuseLastUserMessage && !hiddenUserMessage
      ? messages.find((message) => message.id === agentRun.clientMessageId)
        ?? [...messages].reverse().find((message) => message.role === 'user' && message.text === text)
      : undefined
    const canReuseLastUserMessage = hiddenUserMessage
      ? Boolean(reuseLastUserMessage && agentRun.clientMessageId && agentRun.prompt === text)
      : Boolean(
        reuseLastUserMessage
        && !agentRun.requiresAttachmentReselection
        && retryMessage
        && retryMessage.text === text
        && sameMessageAttachments(retryMessage.attachments, turnAttachments),
      )
    const clientMessageId = canReuseLastUserMessage
      ? hiddenUserMessage ? agentRun.clientMessageId! : retryMessage!.id
      : createAgentMessageId('user')
    const assistantMessageId = canReuseLastUserMessage && agentRun.messageId
      ? agentRun.messageId
      : createAgentMessageId('assistant')
    if (!canReuseLastUserMessage && !hiddenUserMessage) dispatch({
      type: 'addAgentMessage',
      message: {
        id: clientMessageId,
        role: 'user',
        text,
        createdAt: new Date().toISOString(),
        attachments: turnAttachments.length ? turnAttachments.map(attachmentMessageMetadata) : undefined,
      },
    })
    dispatch({ type: 'setAgentDraft', value: '' })
    pendingAttachmentsRef.current = []
    setPendingAttachmentsState([])
    activeTurnAttachments.current = turnAttachments
    cancelPendingAgentText()
    setAgentRun({
      phase: 'preparing',
      prompt: text,
      partialText: '',
      status: turnAttachments.length ? '正在读取附件～' : '正在组织答案～',
      messageId: assistantMessageId,
      clientMessageId,
      hiddenUserMessage,
      contextPackageId,
    })
    if (composerRef.current) composerRef.current.style.height = 'auto'

    const runId = `run-${Date.now()}`
    const controller = new AbortController()
    activeRun.current = runId
    activeRequest.current = controller
    beginVoicePlayback(runId)
    void consultation.accessToken('user').then((accessToken) => streamAgentResponse(
      {
        text,
        threadId: state.agentConversationId,
        clientMessageId,
        finalResponseId: state.finalResponseId,
        packageId: contextPackageId,
        consultationAppointmentId: consultation.mode === 'server' ? options.consultationAppointmentId ?? readPostconsultReference() : undefined,
        commercialContext: buildAgentCommercialContext(state),
        attachments: turnAttachments,
        accessToken,
      },
      {
        signal: controller.signal,
        onAccepted: () => {
          if (activeRun.current !== runId) return
          composerRef.current?.blur()
        },
        onStatus: (status) => {
          if (activeRun.current !== runId) return
          setAgentRun((current) => current.messageId === assistantMessageId
            ? { ...current, phase: 'preparing', prompt: text, status }
            : current)
        },
        onDelta: (partialText) => {
          if (activeRun.current !== runId) return
          appendVoiceText(runId, partialText)
          queueAgentText(runId, text, assistantMessageId, partialText)
        }
      },
    )).then(async (response) => {
      if (activeRun.current !== runId) return
      // The application SSE normally emits the final cumulative text from
      // message.completed. Keep this defensive append so a compatible
      // backend that only emits run.completed still gets narrated in full.
      appendVoiceText(runId, response.text)
      await waitForAgentTextPaint(runId, text, assistantMessageId, response.text)
      if (activeRun.current !== runId) return
      finishVoicePlayback(runId)
      activeRun.current = undefined
      activeRequest.current = undefined
      releaseAttachmentPreviews(activeTurnAttachments.current)
      activeTurnAttachments.current = []
      dispatch({ type: 'addAgentMessage', message: { id: assistantMessageId, role: 'assistant', text: response.text, createdAt: new Date().toISOString(), risk: response.risk, recommendation: response.recommendation, citations: response.citations }, finalResponseId: response.final_response_id })
      setAgentRun(initialAgentRun())
    }).catch((error: unknown) => {
      if (activeRun.current !== runId) return
      cancelVoicePlayback()
      flushPendingAgentText()
      activeRun.current = undefined
      activeRequest.current = undefined
      if (error instanceof DOMException && error.name === 'AbortError') return
      const requestFailed = error instanceof AgentRequestError
      if (requestFailed && [403, 404].includes(error.status ?? 0)) {
        delete postconsultReferences.current[currentPostconsultKey]
        try { sessionStorage.removeItem(currentPostconsultKey) } catch { /* Optional cache. */ }
      }
      const phase = requestFailed && !error.retryable ? 'error' : 'disconnected'
      if (!hiddenUserMessage) dispatch({ type: 'setAgentDraft', value: text })
      restoreActiveTurnAttachments()
      setAgentRun((current) => ({
        ...current,
        phase,
        prompt: text,
        status: '',
        messageId: assistantMessageId,
        clientMessageId,
        requiresAttachmentReselection: false,
        detail: requestFailed ? error.message : navigator.onLine ? '连接暂时中断，可以重试这次回复。' : '当前处于离线状态，联网后可以重试。'
      }))
    })
  }

  const useQuickAction = (prompt: string) => {
    if (composerBusy) return
    send(prompt)
  }

  useEffect(() => {
    const params = new URLSearchParams(location.search)
    if (params.get('postconsult') !== '1' || composerBusy || !isActive) return
    const appointmentId = params.get('appointmentId')
    if (!appointmentId) return
    if (readPostconsultReference() === appointmentId) {
      navigate('/app/agent', { replace: true })
      return
    }
    const requestKey = `${currentPostconsultKey}:${appointmentId}`
    if (postconsultRequest.current === requestKey) return
    postconsultRequest.current = requestKey
    postconsultReferences.current[currentPostconsultKey] = appointmentId
    try { sessionStorage.setItem(currentPostconsultKey, appointmentId) } catch { /* In-memory scope still works. */ }
    const relatedAppointment = state.appointments.find(item => item.id === appointmentId)
    const relatedPackage = state.packages.find(item => item.name === relatedAppointment?.serviceName)
    send(postconsultPrompt, false, { hiddenUserMessage: true, consultationAppointmentId: appointmentId, contextPackageId: relatedPackage?.id })
    navigate('/app/agent', { replace: true })
  }, [composerBusy, location.search, currentPostconsultKey, isActive, navigate])

  useEffect(() => {
    const params = new URLSearchParams(location.search)
    if (params.get('preconsult') !== '1' || composerBusy) return
    const packageId = params.get('packageId') || state.order?.packageId || state.selectedPackageId
    const packageItem = state.packages.find((item) => item.id === packageId)
    if (!packageItem) return
    const requestKey = `${state.agentConversationId}:${packageItem.id}`
    if (preconsultRequest.current === requestKey) return
    preconsultRequest.current = requestKey
    delete postconsultReferences.current[currentPostconsultKey]
    try { sessionStorage.removeItem(currentPostconsultKey) } catch { /* Optional cache. */ }
    const prompt = agentPreconsultPrompt(packageItem.name, state.appointment?.intakeSubmitted ? state.intake : undefined)
    send(prompt, false, { hiddenUserMessage: true, contextPackageId: packageItem.id })
    navigate('/app/agent', { replace: true })
  }, [composerBusy, location.search, navigate, state.agentConversationId, state.order?.packageId, state.packages, state.selectedPackageId])

  const stop = () => {
    if (!isRunning) return
    const cancelledRun = agentRun
    cancelVoicePlayback()
    flushPendingAgentText()
    activeRun.current = undefined
    activeRequest.current?.abort()
    activeRequest.current = undefined
    if (!cancelledRun.hiddenUserMessage) dispatch({ type: 'setAgentDraft', value: cancelledRun.prompt })
    restoreActiveTurnAttachments()
    setAgentRun({ ...cancelledRun, phase: 'cancelRequested', status: '', detail: '正在请求服务端停止' })
    window.setTimeout(() => setAgentRun((current) => current.messageId === cancelledRun.messageId && current.phase === 'cancelRequested'
      ? { ...current, phase: 'cancelled', status: '', detail: '已停止本次回复' }
      : current), 120)
  }

  const requestNewSession = () => {
    if (isRunning) return
    cancelVoicePlayback()
    const conversationId = createAgentConversationId()
    activeConversation.current = conversationId
    dispatch({ type: 'startAgentConversation', conversationId, archive: hasCurrentConversation ? currentConversation : undefined })
    cancelPendingAgentText()
    setAgentRun(initialAgentRun())
    setHistoryOpen(false)
    setAttachmentOpen(false)
    setCapabilityNotice('')
    discardPendingAttachments()
    setShowEarlier(false)
    setShowLatest(false)
    followLatest.current = true
  }

  const switchConversation = (conversation: AgentConversation) => {
    if (conversation.id === state.agentConversationId) {
      setHistoryOpen(false)
      return
    }
    if (isRunning) return
    cancelVoicePlayback()
    activeConversation.current = conversation.id
    dispatch({ type: 'switchAgentConversation', conversationId: conversation.id, current: hasCurrentConversation ? currentConversation : undefined })
    cancelPendingAgentText()
    setAgentRun(recoverInterruptedAgentRun(conversation.messages))
    setHistoryOpen(false)
    setAttachmentOpen(false)
    setCapabilityNotice('')
    discardPendingAttachments()
    setShowEarlier(false)
    setShowLatest(false)
    followLatest.current = true
  }

  const openCommercialRecommendation = (recommendation: NonNullable<AgentMessage['recommendation']>) => {
    if (recommendation.action === 'book_owned_service') {
      dispatch({ type: 'activateService', packageId: recommendation.packageId })
      const expertSearch = recommendation.ibclcId ? `?ibclc=${encodeURIComponent(recommendation.ibclcId)}` : ''
      navigate(`/app/appointment${expertSearch}`)
      return
    }
    if (recommendation.action === 'open_owned_service') {
      dispatch({ type: 'activateService', packageId: recommendation.packageId })
      navigate('/app/home')
      return
    }
    navigate(`/app/services/${recommendation.packageId}`)
  }

  const retryable = agentRun.phase === 'disconnected' || agentRun.phase === 'error' || agentRun.phase === 'cancelled'
  const runIsError = agentRun.phase === 'disconnected' || agentRun.phase === 'error'
  return <div className={`agent-page ${isRunning ? 'is-streaming' : ''} ${agentRun.phase === 'streaming' && agentRun.partialText ? 'is-replying' : ''} ${voicePhase === 'playing' ? 'is-voice-playing' : ''}`}>
    <div className="agent-main-layer" aria-hidden={historyOpen || undefined} inert={historyOpen || undefined}>
      <span className="sr-only" role="status" aria-live="polite">{voicePhase === 'playing' ? '正在播报 Cozymate 回复（AI 合成语音）' : voicePhase === 'connecting' ? '正在连接语音' : ''}</span>
      <header className="agent-toolbar" aria-label="Cozymate 对话工具栏">
        <div className="agent-toolbar-slot">
          <button ref={historyTriggerRef} className="agent-toolbar-button" aria-label="打开会话历史" aria-expanded={historyOpen} onClick={() => { setHistoryOpen(true); setAttachmentOpen(false) }}><Icon name="menu" /></button>
        </div>
        <h1 className="agent-toolbar-title">Cozymate</h1>
        <div className="agent-toolbar-actions">
          <button
            type="button"
            className={`agent-voice-toggle ${voiceEnabled ? 'enabled' : 'disabled'}`}
            role="switch"
            aria-checked={voiceEnabled}
            aria-label={voiceEnabled ? '关闭实时语音播报' : '开启实时语音播报'}
            title={voiceEnabled ? '关闭实时语音播报' : '开启实时语音播报'}
            onClick={toggleVoicePlayback}
          >
            <span className="agent-voice-toggle-track"><span className="agent-voice-toggle-thumb"><Icon name={voiceEnabled ? 'volume' : 'volume-off'} /></span></span>
          </button>
          <button className="agent-toolbar-button" aria-label="新建会话" disabled={composerBusy} onClick={requestNewSession}><Icon name="plus" /></button>
        </div>
      </header>

      <div ref={threadRef} className="chat-thread" role="log" aria-label="与 Cozymate 的对话" aria-live="polite" aria-relevant="additions text" onScroll={handleThreadScroll}>
        {hiddenCount > 0 && <button className="chat-history-toggle" onClick={revealEarlier}>加载更早的 {hiddenCount} 条消息</button>}
        {visibleMessages.map((message) => {
          const isGreeting = message.role === 'assistant' && message.id.startsWith('welcome')
          const isLiveAssistant = message.role === 'assistant' && message.id === agentRun.messageId && agentRun.phase !== 'idle'
          const recommendedPackage = message.recommendation
            ? state.packages.find((item) => item.id === message.recommendation?.packageId)
            : undefined
          const recommendedExpert = message.recommendation?.ibclcName?.replace(/,?\s*IBCLC$/i, '')
          const recommendationButton = message.recommendation?.action === 'book_owned_service'
            ? '使用已有权益'
            : message.recommendation?.action === 'open_owned_service' ? '查看我的服务' : '查看支持方案'
          return <article key={message.id} className={`chat-row ${message.role} ${isGreeting ? 'greeting' : ''} ${isLiveAssistant ? `agent-run-row ${agentRun.phase}` : ''}`} aria-label={isLiveAssistant ? 'Cozymate 回复状态' : undefined} role={isLiveAssistant ? (runIsError ? 'alert' : 'status') : undefined}>
          <div className={`bubble-wrap${message.role === 'assistant' ? ' assistant-response-group' : ''}`}>
            <span className="sr-only">{message.role === 'assistant' ? 'Cozymate' : '你'}</span>
            {isLiveAssistant && agentRun.status && isRunning && <span className="agent-run-status">{agentRun.status}</span>}
            {(message.role === 'user' || message.text) && <div className={`chat-bubble ${message.role} ${message.attachments?.length ? 'has-attachments' : ''}`}>{message.role === 'assistant'
              ? <AgentMarkdownText text={message.text} />
              : <><AgentMessageAttachments attachments={message.attachments} />{message.text && <span className="agent-user-message-text">{message.text}</span>}</>}</div>}
            {message.role === 'assistant' && message.recommendation && <section className="recommendation-card" aria-label="推荐专家服务包"><div className="recommendation-card-main"><span className="recommendation-card-icon"><Icon name="users" /></span><div><span className="recommendation-kicker">推荐专家服务包</span><strong>{recommendedPackage?.name ?? (recommendedExpert ? `可以问问 ${recommendedExpert}` : '和 IBCLC 一起看看')}</strong><span>{message.recommendation.reason}</span></div>{recommendedPackage && <strong className="recommendation-price">${recommendedPackage.price}</strong>}</div>{recommendedPackage && <div className="recommendation-card-meta"><span>{recommendedPackage.durationDays} 天支持</span><span>{recommendedPackage.sessions} 次 IBCLC 咨询</span></div>}<Button size="sm" variant="soft" onClick={() => openCommercialRecommendation(message.recommendation!)}>{recommendationButton} <Icon name="arrow" /></Button></section>}
            {isLiveAssistant && !message.text && runIsError && <p className="agent-run-fallback">这次没有拿到回复。</p>}
            <AgentCitations message={message} />
            {message.risk && message.risk !== 'R0' && <div className={`risk-callout ${message.risk === 'R3' ? 'critical' : 'attention'}`} role="alert"><Icon name="shield" /><div><strong>{message.risk === 'R3' ? '请立即获得线下帮助' : '建议尽快获得专业评估'}</strong><span>{message.risk === 'R3' ? '联系当地急救服务或前往最近的急诊。' : '记录发生时间和变化，并联系医疗服务提供者。'}</span></div></div>}
            {isLiveAssistant && agentRun.detail && <div className="agent-run-detail"><Icon name={runIsError ? 'wifi' : 'stop'} /><span>{agentRun.detail}</span></div>}
            {isLiveAssistant && retryable && (agentRun.prompt || pendingAttachments.length > 0) && (!agentRun.requiresAttachmentReselection || pendingAttachments.length > 0) && <Button size="sm" variant="soft" onClick={() => send(agentRun.prompt, true, { hiddenUserMessage: agentRun.hiddenUserMessage, contextPackageId: agentRun.contextPackageId })}>重试</Button>}
          </div>
        </article>})}
      </div>

      {showLatest && <button className="agent-latest-button" onClick={() => scrollToLatest()}><span aria-hidden="true">↓</span> 回到最新消息</button>}

      <div className="agent-composer-area">
        {pendingAttachments.length > 0 && <div className="agent-pending-attachments" role="list" aria-label="待发送附件">{pendingAttachments.map((attachment) => <div key={attachment.id} className="agent-pending-attachment" role="listitem">
          <span className={`agent-pending-attachment-preview ${attachment.kind}`}>
            {attachment.previewUrl ? <img src={attachment.previewUrl} alt="" /> : <Icon name="file" />}
          </span>
          <span className="agent-pending-attachment-copy"><strong>{attachment.name}</strong><small>{formatAgentAttachmentSize(attachment.size)}</small></span>
          <button type="button" aria-label={`移除 ${attachment.name}`} onClick={() => removePendingAttachment(attachment.id)}>×</button>
        </div>)}</div>}
        {attachmentsPreparing && <div className="agent-toast neutral" role="status"><span>正在准备附件…</span></div>}
        {capabilityNotice && <div className="agent-toast neutral" role="status"><span>{capabilityNotice}</span><button className="notice-dismiss" aria-label="关闭提示" onClick={() => setCapabilityNotice('')}>×</button></div>}
        {voiceError && <div className="agent-toast neutral" role="status"><span>{voiceError}</span><button className="text-button" disabled={composerBusy || !voiceEnabled} onClick={replayVoice}>播放回复</button><button className="notice-dismiss" aria-label="关闭语音提示" onClick={() => setVoiceError('')}>×</button></div>}
        <div className="agent-shortcuts" aria-label="智能体快捷功能">
          <div className="agent-shortcut-list">
            {agentQuickActions.map((action) => <button key={action.id} type="button" className="agent-shortcut" disabled={composerBusy} onClick={() => useQuickAction(action.prompt)}>{action.label}</button>)}
          </div>
        </div>
        <div className="composer">
          <div ref={attachmentControlRef} className="agent-attachment-control">
            <input ref={cameraInputRef} className="agent-hidden-file-input" type="file" accept="image/*" capture="environment" tabIndex={-1} onChange={(event) => { const files = Array.from(event.currentTarget.files ?? []); event.currentTarget.value = ''; void handleAttachmentSelection(files, 'camera') }} />
            <input ref={photoInputRef} className="agent-hidden-file-input" type="file" accept={AGENT_IMAGE_ACCEPT} multiple tabIndex={-1} onChange={(event) => { const files = Array.from(event.currentTarget.files ?? []); event.currentTarget.value = ''; void handleAttachmentSelection(files, 'photo') }} />
            <input ref={fileInputRef} className="agent-hidden-file-input" type="file" accept={AGENT_FILE_ACCEPT} multiple tabIndex={-1} onChange={(event) => { const files = Array.from(event.currentTarget.files ?? []); event.currentTarget.value = ''; void handleAttachmentSelection(files, 'file') }} />
            <button ref={attachmentTriggerRef} className="agent-attachment-button" aria-label="添加附件" aria-haspopup="menu" aria-expanded={attachmentOpen} disabled={composerBusy} onClick={() => { setAttachmentOpen(!attachmentOpen); setHistoryOpen(false) }}><Icon name="plus" /></button>
            {attachmentOpen && <div ref={attachmentMenuRef} className="agent-attachment-popover" role="menu" aria-label="添加到对话">
              <button role="menuitem" onClick={() => chooseAttachment(cameraInputRef.current)}><span className="agent-attachment-icon"><Icon name="camera" /></span><span>相机<small>拍摄一张照片</small></span></button>
              <button role="menuitem" onClick={() => chooseAttachment(photoInputRef.current)}><span className="agent-attachment-icon"><Icon name="image" /></span><span>照片<small>JPG、PNG、WebP</small></span></button>
              <button role="menuitem" onClick={() => chooseAttachment(fileInputRef.current)}><span className="agent-attachment-icon"><Icon name="file" /></span><span>文件<small>PDF、Word、表格等</small></span></button>
            </div>}
          </div>
          <textarea ref={composerRef} aria-label="输入消息" value={state.agentDraft} disabled={isRunning} onChange={(event) => { dispatch({ type: 'setAgentDraft', value: event.target.value }); setCapabilityNotice('') }} onKeyDown={(event) => { if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) { event.preventDefault(); send() } }} placeholder="和 Cozymate 聊聊..." rows={1} maxLength={2000} />
          {isRunning ? <button className="agent-send-button active" aria-label={agentRun.phase === 'cancelRequested' ? '正在停止' : '停止生成'} onClick={stop} disabled={agentRun.phase === 'cancelRequested'}><Icon name="stop" /></button> : <button className="agent-send-button" aria-label="发送" onClick={() => send()} disabled={attachmentsPreparing || (!state.agentDraft.trim() && !pendingAttachments.length)}><Icon name="send" /></button>}
        </div>
      </div>
    </div>

    {historyOpen && <div className="agent-history-layer">
      <div className="agent-history-scrim" aria-hidden="true" onMouseDown={() => setHistoryOpen(false)} />
      <section ref={historyPanelRef} className="agent-history-panel" role="dialog" aria-modal="true" aria-labelledby="agent-history-title" onPointerDown={(event) => { historySwipeStart.current = { x: event.clientX, y: event.clientY, at: performance.now() } }} onPointerCancel={() => { historySwipeStart.current = undefined }} onPointerUp={(event) => {
        const start = historySwipeStart.current
        historySwipeStart.current = undefined
        if (!start) return
        const deltaX = event.clientX - start.x
        const deltaY = event.clientY - start.y
        if (deltaX < -64 && Math.abs(deltaX) > Math.abs(deltaY) * 1.25 && performance.now() - start.at < 700) setHistoryOpen(false)
      }}>
        <div className="agent-history-header"><h2 id="agent-history-title">会话历史</h2><button aria-label="关闭会话历史" onClick={() => setHistoryOpen(false)}>×</button></div>
        {isRunning && <p className="agent-history-lock-note">回复完成后可切换会话</p>}
        {conversationItems.length ? <div className="agent-history-list">{conversationItems.map((conversation) => {
          const isCurrent = conversation.id === state.agentConversationId
          return <button key={conversation.id} className={`agent-history-item ${isCurrent ? 'current' : ''}`} aria-current={isCurrent ? 'true' : undefined} disabled={isRunning && !isCurrent} onClick={() => switchConversation(conversation)}><Icon name="chat" /><span><strong>{conversation.title}</strong><time dateTime={conversation.updatedAt}>{formatAgentConversationTime(conversation.updatedAt)}</time></span></button>
        })}</div> : <div className="agent-history-empty"><Icon name="chat" /><strong>还没有历史会话</strong></div>}
      </section>
    </div>}
  </div>
}

type AppScheduleItem =
  | { id: string; kind: 'task'; dateKey: string; task: CareTask }
  | { id: string; kind: 'appointment'; dateKey: string; appointment: Appointment }
  | { id: string; kind: 'personal'; dateKey: string; schedule: PersonalSchedule }

const taskStatusLabels: Record<CareTask['status'], string> = {
  pending: '待完成',
  in_progress: '进行中',
  completed: '已完成',
  skipped: '已跳过',
  expired: '已过期'
}

function parseCalendarDate(value: string) {
  const [year, month, day] = value.split('-').map(Number)
  return new Date(year, month - 1, day)
}

function addCalendarDays(value: Date, amount: number) {
  const date = new Date(value)
  date.setDate(date.getDate() + amount)
  return date
}

function taskScheduleDate(plan: CarePlan, task: CareTask, index: number) {
  if (task.scheduledDate && /^\d{4}-\d{2}-\d{2}$/.test(task.scheduledDate)) return task.scheduledDate
  const published = plan.publishedAt ? new Date(plan.publishedAt) : new Date()
  const base = Number.isNaN(published.getTime()) ? new Date() : published
  const offset = task.dueLabel.includes('明天') ? 1
    : task.dueLabel.includes('后天') ? 2
      : task.dueLabel.includes('本周') ? 6
        : task.dueLabel.includes('今天') ? 0
          : index
  return localDateKey(addCalendarDays(base, offset))
}

function calendarMonthDays(anchor: Date) {
  const first = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
  const leadingDays = (first.getDay() + 6) % 7
  const daysInMonth = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 0).getDate()
  const cellCount = leadingDays + daysInMonth <= 35 ? 35 : 42
  const gridStart = addCalendarDays(first, -leadingDays)
  return Array.from({ length: cellCount }, (_, index) => addCalendarDays(gridStart, index))
}

function taskTone(task: CareTask): 'neutral' | 'rose' | 'green' | 'amber' | 'blue' {
  if (task.status === 'completed') return 'green'
  if (task.status === 'skipped' || task.status === 'expired') return 'neutral'
  if (task.category === '喂养') return 'rose'
  if (task.category === '观察') return 'blue'
  return 'amber'
}

function appointmentScheduleStatus(status: Appointment['status']): { label: string; tone: 'neutral' | 'green' | 'amber' | 'blue' | 'red' } {
  if (status === 'held') return { label: '待确认', tone: 'amber' }
  if (status === 'confirmed') return { label: '已确认', tone: 'blue' }
  if (status === 'in_progress') return { label: '进行中', tone: 'green' }
  if (status === 'completed') return { label: '已完成', tone: 'green' }
  if (status === 'conflict') return { label: '需调整', tone: 'red' }
  return { label: '未出席', tone: 'neutral' }
}

function scheduleItemTime(item: AppScheduleItem) {
  if (item.kind === 'appointment') return item.appointment.start.slice(11, 16)
  if (item.kind === 'personal') return item.schedule.time
  return ''
}

function PlanPage() {
  const { state, dispatch, completeTask, documentation } = useProduct()
  const navigate = useNavigate()
  const todayKey = localDateKey()
  const today = parseCalendarDate(todayKey)
  const [selectedDate, setSelectedDate] = useState(todayKey)
  const [monthAnchor, setMonthAnchor] = useState(() => new Date(today.getFullYear(), today.getMonth(), 1))
  const [scheduleComposerOpen, setScheduleComposerOpen] = useState(false)
  const [scheduleBeingEdited, setScheduleBeingEdited] = useState<PersonalSchedule>()
  const [schedulePendingDelete, setSchedulePendingDelete] = useState<PersonalSchedule>()
  const [scheduleDraft, setScheduleDraft] = useState({ title: '', date: todayKey, time: '09:00', note: '' })
  useEffect(() => {
    const closeOpenMenus = (event: PointerEvent) => {
      const target = event.target
      if (!(target instanceof Node)) return
      document.querySelectorAll<HTMLDetailsElement>('.schedule-page .task-menu[open], .schedule-page .app-calendar-service-picker[open]').forEach((menu) => {
        if (!menu.contains(target)) menu.removeAttribute('open')
      })
    }
    document.addEventListener('pointerdown', closeOpenMenus)
    return () => document.removeEventListener('pointerdown', closeOpenMenus)
  }, [])
  const activeAppointment = state.appointment
  const plan = documentation.mode === 'server' && activeAppointment
    ? documentation.records[activeAppointment.id]?.currentPublication
    : state.carePlan
  const activeServices = useMemo(() => {
    const episodes = new Map(state.episodes.map((episode) => [episode.id, episode]))
    if (state.episode) episodes.set(state.episode.id, state.episode)
    return [...episodes.values()].flatMap((episode) => {
      if (episode.status !== 'active') return []
      const order = state.orders.find((item) => item.id === episode.orderId && item.status === 'paid')
      const packageItem = state.packages.find((item) => item.id === order?.packageId)
      if (!order || !packageItem) return []
      const startKey = appointmentDateKey(episode.startedAt, state.user.timezone)
      const endKey = appointmentDateKey(episode.endsAt, state.user.timezone)
      const period = [startKey, endKey].map((key) => {
        const [, month, day] = key.split('-')
        return `${Number(month)}/${Number(day)}`
      }).join('–')
      return [{ episode, packageItem, startKey, endKey, period }]
    }).sort((a, b) => a.endKey.localeCompare(b.endKey) || b.startKey.localeCompare(a.startKey))
  }, [state.episode, state.episodes, state.orders, state.packages, state.user.timezone])
  const [focusedServiceId, setFocusedServiceId] = useState<string>()
  const focusedService = activeServices.find((service) => service.episode.id === focusedServiceId)
  const displayedServices = focusedService ? [focusedService] : activeServices
  const selectedDateServices = useMemo(() => activeServices.filter((service) => selectedDate >= service.startKey && selectedDate <= service.endKey), [activeServices, selectedDate])
  const selectedServiceLabel = selectedDateServices.length <= 2
    ? selectedDateServices.map((service) => service.packageItem.name).join('、')
    : `${selectedDateServices[0]?.packageItem.name}等 ${selectedDateServices.length} 项`
  const servicePickerLabel = focusedService?.packageItem.name
    ?? (selectedServiceLabel ? selectedServiceLabel : `全部服务 · ${activeServices.length} 项`)
  useEffect(() => {
    if (focusedServiceId && !activeServices.some((service) => service.episode.id === focusedServiceId)) setFocusedServiceId(undefined)
  }, [activeServices, focusedServiceId])
  useEffect(() => {
    if (documentation.mode !== 'server' || !activeAppointment || activeAppointment.status !== 'completed') return
    void documentation.load(activeAppointment.id, 'user')
  }, [activeAppointment?.id, activeAppointment?.status, documentation.load, documentation.mode])
  const completed = plan?.tasks.filter((task) => task.status === 'completed').length ?? 0
  const setPlanTaskStatus = (task: CareTask, status: CareTask['status']) => {
    if (documentation.mode === 'server' && activeAppointment) {
      void documentation.updateTask(activeAppointment.id, task.id, status)
      return
    }
    dispatch({ type: 'updateTask', id: task.id, status })
  }
  const togglePlanTask = (task: CareTask) => {
    if (documentation.mode === 'server') {
      setPlanTaskStatus(task, task.status === 'completed' ? 'pending' : 'completed')
    } else {
      completeTask(task.id)
    }
  }
  const appointments = useMemo(() => state.appointment && state.appointment.status !== 'cancelled'
    ? [state.appointment]
    : [], [state.appointment])
  const scheduleItems = useMemo<AppScheduleItem[]>(() => {
    const taskItems: AppScheduleItem[] = plan?.tasks.map((task, index) => ({ id: task.id, kind: 'task', dateKey: taskScheduleDate(plan, task, index), task })) ?? []
    const appointmentItems: AppScheduleItem[] = appointments.map((appointment) => ({ id: appointment.id, kind: 'appointment', dateKey: appointmentDateKey(appointment.start, appointment.timezone), appointment }))
    const personalItems: AppScheduleItem[] = (state.personalSchedules ?? []).map((schedule) => ({ id: schedule.id, kind: 'personal', dateKey: schedule.date, schedule }))
    return [...taskItems, ...appointmentItems, ...personalItems]
  }, [appointments, plan, state.personalSchedules])
  const itemsByDate = useMemo(() => {
    const grouped = new Map<string, AppScheduleItem[]>()
    scheduleItems.forEach((item) => grouped.set(item.dateKey, [...(grouped.get(item.dateKey) ?? []), item]))
    return grouped
  }, [scheduleItems])
  const selectedItems = useMemo(() => [...(itemsByDate.get(selectedDate) ?? [])].sort((a, b) => {
    if (a.kind === 'task' && b.kind !== 'task') return -1
    if (a.kind !== 'task' && b.kind === 'task') return 1
    return scheduleItemTime(a).localeCompare(scheduleItemTime(b))
  }), [itemsByDate, selectedDate])
  const nextTaskId = useMemo(() => scheduleItems
    .filter((item): item is Extract<AppScheduleItem, { kind: 'task' }> => item.kind === 'task' && ['pending', 'in_progress'].includes(item.task.status))
    .sort((a, b) => a.dateKey.localeCompare(b.dateKey))[0]?.task.id, [scheduleItems])
  const monthDays = useMemo(() => calendarMonthDays(monthAnchor), [monthAnchor])
  const selectedDateValue = parseCalendarDate(selectedDate)
  const selectedDateLabel = new Intl.DateTimeFormat('zh-CN', { month: 'long', day: 'numeric', weekday: 'long' }).format(selectedDateValue)
  const monthLabel = new Intl.DateTimeFormat('zh-CN', { year: 'numeric', month: 'long' }).format(monthAnchor)
  const selectDate = (date: Date) => {
    setSelectedDate(localDateKey(date))
    if (date.getMonth() !== monthAnchor.getMonth() || date.getFullYear() !== monthAnchor.getFullYear()) setMonthAnchor(new Date(date.getFullYear(), date.getMonth(), 1))
  }
  const shiftMonth = (amount: number) => {
    const nextMonth = new Date(monthAnchor.getFullYear(), monthAnchor.getMonth() + amount, 1)
    setMonthAnchor(nextMonth)
    setSelectedDate(localDateKey(nextMonth))
  }
  const openAppointment = (appointment: Appointment) => {
    if (appointment.attendanceOutcome) navigate(`/app/consult/${appointment.id}/room`)
    else if (appointment.status === 'completed') navigate(`/app/consultations/${appointment.id}/summary`)
    else navigate(`/app/appointments/${appointment.id}`)
  }
  const openScheduleComposer = () => {
    setScheduleBeingEdited(undefined)
    setScheduleDraft((draft) => ({ ...draft, date: selectedDate }))
    setScheduleComposerOpen(true)
  }
  const openScheduleEditor = (schedule: PersonalSchedule) => {
    setScheduleBeingEdited(schedule)
    setScheduleDraft({ title: schedule.title, date: schedule.date, time: schedule.time, note: schedule.note ?? '' })
    setScheduleComposerOpen(true)
  }
  const closeScheduleComposer = () => {
    setScheduleComposerOpen(false)
    if (scheduleBeingEdited) {
      setScheduleBeingEdited(undefined)
      setScheduleDraft({ title: '', date: selectedDate, time: '09:00', note: '' })
    }
  }
  const savePersonalSchedule = () => {
    const title = scheduleDraft.title.trim()
    if (!title || !scheduleDraft.date || !scheduleDraft.time) return
    const schedule: PersonalSchedule = {
      id: scheduleBeingEdited?.id ?? `schedule-${Date.now()}`,
      title,
      date: scheduleDraft.date,
      time: scheduleDraft.time,
      note: scheduleDraft.note.trim() || undefined,
      createdAt: scheduleBeingEdited?.createdAt ?? new Date().toISOString()
    }
    dispatch({ type: scheduleBeingEdited ? 'updatePersonalSchedule' : 'addPersonalSchedule', schedule })
    const targetDate = parseCalendarDate(schedule.date)
    setSelectedDate(schedule.date)
    setMonthAnchor(new Date(targetDate.getFullYear(), targetDate.getMonth(), 1))
    setScheduleComposerOpen(false)
    setScheduleBeingEdited(undefined)
    setScheduleDraft({ title: '', date: schedule.date, time: '09:00', note: '' })
  }
  const deletePersonalSchedule = () => {
    if (!schedulePendingDelete) return
    dispatch({ type: 'removePersonalSchedule', id: schedulePendingDelete.id })
    setSchedulePendingDelete(undefined)
  }

  return <div className="page-stack plan-page schedule-page">
    <section className="app-calendar" aria-labelledby="app-calendar-month">
      <div className="app-calendar-body">
        <div className="app-calendar-toolbar"><span className="app-calendar-leading"><button aria-label="上个月" onClick={() => shiftMonth(-1)}>‹</button></span><div className="app-calendar-heading"><h2 id="app-calendar-month">{monthLabel}</h2><p>查看每天的日程安排</p></div><span className="app-calendar-actions"><button aria-label="下个月" onClick={() => shiftMonth(1)}>›</button></span></div>
        <div className="app-calendar-weekdays" aria-hidden="true">{['一', '二', '三', '四', '五', '六', '日'].map((label) => <span key={label}>{label}</span>)}</div>
        <div className="app-calendar-grid" role="grid" aria-label={`${monthLabel}日历`}>
          {monthDays.map((date) => {
            const key = localDateKey(date)
            const dayItems = itemsByDate.get(key) ?? []
            const hasTask = dayItems.some((item) => item.kind === 'task')
            const hasAppointment = dayItems.some((item) => item.kind === 'appointment')
            const hasPersonal = dayItems.some((item) => item.kind === 'personal')
            const dayServices = displayedServices.filter((service) => key >= service.startKey && key <= service.endKey)
            const inCurrentService = dayServices.length > 0
            const inMonth = date.getMonth() === monthAnchor.getMonth()
            const dateLabel = new Intl.DateTimeFormat('zh-CN', { month: 'long', day: 'numeric', weekday: 'short' }).format(date)
            const eventTypes = [hasTask ? '行动任务' : '', hasAppointment ? '咨询预约' : '', hasPersonal ? '个人日程' : ''].filter(Boolean).join('、')
            const serviceDescription = dayServices.length
              ? `，覆盖${dayServices.length}个服务包${dayServices.length <= 3 ? `：${dayServices.map((service) => service.packageItem.name).join('、')}` : ''}`
              : ''
            return <button key={key} role="gridcell" aria-label={`${dateLabel}${dayItems.length ? `，${dayItems.length} 项安排：${eventTypes}` : '，无安排'}${serviceDescription}`} aria-pressed={key === selectedDate} aria-current={key === todayKey ? 'date' : undefined} className={`${inMonth ? '' : 'outside'} ${inCurrentService ? 'in-service' : ''} ${key === todayKey ? 'today' : ''} ${key === selectedDate ? 'selected' : ''} ${dayItems.length ? 'has-events' : ''}`} onClick={() => selectDate(date)}><span className="app-calendar-day-number">{date.getDate()}</span>{(dayItems.length > 0 || key === todayKey) && <span className="app-calendar-markers" aria-hidden="true"><i /></span>}</button>
          })}
        </div>
        {activeServices.length > 0 && <div className="app-calendar-service" aria-label={`浅绿色日期处于服务周期内，当前显示${focusedService ? focusedService.packageItem.name : '全部服务'}的周期`}>
          <span className="app-calendar-service-count">浅绿色为服务期</span>
          {activeServices.length === 1 && <span className="app-calendar-service-focus" aria-live="polite"><strong>{activeServices[0].packageItem.name}</strong><span>{activeServices[0].period} · IBCLC 咨询 · 余 {activeServices[0].episode.remainingSessions} 次</span></span>}
          {activeServices.length > 1 && <details className="app-calendar-service-picker"><summary aria-label={`当前显示${focusedService ? focusedService.packageItem.name : `全部${activeServices.length}个服务`}的周期，点击切换`}>{servicePickerLabel}</summary><div className="app-calendar-service-menu" role="group" aria-label="切换日历显示的服务包">
            <button type="button" className={!focusedService ? 'active' : ''} onClick={(event) => { setFocusedServiceId(undefined); event.currentTarget.closest('details')?.removeAttribute('open') }}><span><strong>全部服务</strong><small>同时显示所有服务周期</small></span><small>{activeServices.length} 项</small></button>
            {activeServices.map((service) => <button key={service.episode.id} type="button" className={focusedService?.episode.id === service.episode.id ? 'active' : ''} onClick={(event) => { setFocusedServiceId(service.episode.id); event.currentTarget.closest('details')?.removeAttribute('open') }}><span><strong>{service.packageItem.name}</strong><small>{service.period}</small></span><small>IBCLC 咨询 · 余 {service.episode.remainingSessions} 次</small></button>)}
          </div></details>}
        </div>}
      </div>
      <div className="schedule-day" aria-label={`${selectedDateLabel}的日程安排`}>
        {selectedItems.length > 0 ? <div className="schedule-agenda-list">{selectedItems.map((item) => {
          if (item.kind === 'appointment') {
            const status = appointmentScheduleStatus(item.appointment.status)
            return <article key={`appointment-${item.id}`} className="schedule-agenda-item appointment"><div className="schedule-agenda-icon"><Icon name="video" /></div><div className="schedule-agenda-copy"><div className="schedule-agenda-meta"><span>{formatAppointmentRange(item.appointment.start, item.appointment.end, item.appointment.timezone)}</span><Badge tone={status.tone}>{status.label}</Badge></div><h3>IBCLC 咨询</h3><p>{item.appointment.ibclcName} · {getAppointmentMinutes(item.appointment.start, item.appointment.end)} 分钟</p></div><button className="schedule-item-action" onClick={() => openAppointment(item.appointment)}>{item.appointment.attendanceOutcome ? '结果' : item.appointment.status === 'completed' ? '总结' : item.appointment.status === 'held' ? '确认' : '查看'}</button></article>
          }
          if (item.kind === 'personal') {
            return <article key={`personal-${item.id}`} className="schedule-agenda-item personal"><div className="schedule-agenda-icon personal"><Icon name="calendar" /></div><div className="schedule-agenda-copy"><div className="schedule-agenda-meta"><span>{item.schedule.time}</span></div><h3>{item.schedule.title}</h3>{item.schedule.note && <p>{item.schedule.note}</p>}</div><details className="task-menu schedule-personal-menu"><summary aria-label={`更多${item.schedule.title}选项`}>•••</summary><div className="task-menu-popover"><button onClick={(event) => { event.currentTarget.closest('details')?.removeAttribute('open'); openScheduleEditor(item.schedule) }}>修改日程</button><button onClick={(event) => { event.currentTarget.closest('details')?.removeAttribute('open'); setSchedulePendingDelete(item.schedule) }}>删除日程</button></div></details></article>
          }
          if (item.kind !== 'task') return null
          const canToggle = item.task.status !== 'skipped' && item.task.status !== 'expired'
          return <article key={`task-${item.id}`} className={`schedule-agenda-item task ${item.task.status === 'completed' ? 'done' : ''} ${item.task.id === nextTaskId ? 'next' : ''}`}><button aria-label={canToggle ? item.task.status === 'completed' ? `标记${item.task.title}未完成` : `完成${item.task.title}` : `${item.task.title}${taskStatusLabels[item.task.status]}`} aria-pressed={item.task.status === 'completed'} className={`schedule-task-toggle ${item.task.status === 'completed' ? 'checked' : ''}`} disabled={!canToggle || documentation.busy} onClick={() => togglePlanTask(item.task)}>{item.task.status === 'completed' ? <Icon name="check" /> : ''}</button><div className="schedule-agenda-copy"><div className="schedule-agenda-meta"><span>全天 · {item.task.dueLabel}</span><Badge tone={taskTone(item.task)}>{taskStatusLabels[item.task.status]}</Badge></div><h3>{item.task.title}</h3><p>{item.task.description}</p></div><details className="task-menu"><summary aria-label={`更多${item.task.title}选项`}>•••</summary><div className="task-menu-popover"><button disabled={documentation.busy} onClick={() => setPlanTaskStatus(item.task, 'in_progress')}>标记进行中</button><button disabled={documentation.busy} onClick={() => setPlanTaskStatus(item.task, 'skipped')}>暂时跳过</button><button disabled={documentation.busy} onClick={() => setPlanTaskStatus(item.task, 'pending')}>恢复待完成</button></div></details></article>
        })}</div> : <div className="schedule-empty"><span className="schedule-empty-icon"><Icon name="calendar" /></span><div><strong>{selectedDate === todayKey ? '今天暂时没有安排' : '这一天没有安排'}</strong><p>{scheduleItems.length ? '可以选择有标记的日期查看安排。' : '你添加的日程、专家方案任务和咨询预约会显示在这里。'}</p></div></div>}
      </div>
    </section>

    <button className="schedule-add-fab" aria-label="添加日程" title="添加日程" onClick={openScheduleComposer}><Icon name="plus" /></button>

    {scheduleComposerOpen && <Modal title={scheduleBeingEdited ? '修改日程' : '添加日程'} className="schedule-add-modal" onClose={closeScheduleComposer}><form className="schedule-add-form" onSubmit={(event) => { event.preventDefault(); savePersonalSchedule() }}>
      <label className="schedule-form-field"><span>日程名称</span><input autoFocus required maxLength={40} value={scheduleDraft.title} onChange={(event) => { const title = event.currentTarget.value; setScheduleDraft((draft) => ({ ...draft, title })) }} placeholder="例如：宝宝体检" /></label>
      <div className="schedule-form-grid"><label className="schedule-form-field"><span>日期</span><input required type="date" value={scheduleDraft.date} onInput={(event) => { const date = event.currentTarget.value; setScheduleDraft((draft) => ({ ...draft, date })) }} /></label><label className="schedule-form-field"><span>开始时间</span><input required type="time" value={scheduleDraft.time} onInput={(event) => { const time = event.currentTarget.value; setScheduleDraft((draft) => ({ ...draft, time })) }} /></label></div>
      <label className="schedule-form-field"><span>备注 <small>选填</small></span><textarea maxLength={120} rows={3} value={scheduleDraft.note} onChange={(event) => { const note = event.currentTarget.value; setScheduleDraft((draft) => ({ ...draft, note })) }} placeholder="需要准备的东西或地点" /></label>
      <Button type="submit" size="lg" disabled={!scheduleDraft.title.trim() || !scheduleDraft.date || !scheduleDraft.time}>{scheduleBeingEdited ? '保存修改' : '添加到日程'}</Button>
    </form></Modal>}

    {schedulePendingDelete && <Modal title="删除日程？" className="booking-cancel-modal schedule-delete-modal" onClose={() => setSchedulePendingDelete(undefined)}><div className="booking-cancel-content"><div className="booking-cancel-summary"><span className="booking-cancel-icon schedule-delete-icon"><Icon name="calendar" /></span><div><strong>{schedulePendingDelete.title}</strong><span>{new Intl.DateTimeFormat('zh-CN', { month: 'long', day: 'numeric', weekday: 'short' }).format(parseCalendarDate(schedulePendingDelete.date))} · {schedulePendingDelete.time}</span></div></div><p>删除后将从日历和当日日程中移除，且无法恢复。</p><div className="booking-cancel-actions"><Button size="lg" onClick={() => setSchedulePendingDelete(undefined)}>保留日程</Button><Button size="lg" variant="danger" onClick={deletePersonalSchedule}>确认删除</Button></div></div></Modal>}

    {documentation.mode === 'server' && documentation.error && <div className="inline-warning" role="alert"><Icon name="note" /><span>{documentation.error}</span></div>}
    {plan && <details className="current-plan-summary"><summary><span className="current-plan-icon"><Icon name="plan" /></span><span className="current-plan-copy"><small>当前照护方案</small><strong>{plan.title}</strong></span><span className="current-plan-count">{completed}/{plan.tasks.length}</span><span className="details-chevron">⌄</span></summary><div className="current-plan-body"><div className="current-plan-version"><Badge tone="green">v{plan.version} · 已发布</Badge><span>{completed} 项已完成</span></div><ProgressBar value={plan.tasks.length ? completed / plan.tasks.length * 100 : 0} tone="green" /><p>{plan.summary}</p><button className="text-button" onClick={() => navigate(activeAppointment ? `/app/consultations/${activeAppointment.id}/summary` : '/app/summary')}>查看周期总结 <Icon name="arrow" /></button></div></details>}
  </div>
}

function MorePage() {
  const { state } = useProduct()
  const navigate = useNavigate()
  return <div className="page-stack more-page">
    <h1 className="sr-only">账号信息</h1>
    <Card className="profile-card account-card">
      <div className="avatar avatar-large" aria-hidden="true">{state.user.avatar}</div>
      <div className="account-identity"><h2>{state.user.name}</h2><p>{state.user.email}</p></div>
      <Button variant="ghost" size="sm" aria-label="管理隐私与授权" onClick={() => navigate('/app/privacy')}>隐私</Button>
    </Card>
  </div>
}

function ServicesPage() {
  const { state } = useProduct()
  const navigate = useNavigate()
  const lactationPackages = state.packages.filter((pkg) => pkg.category === '泌乳支持')
  const purchasedPackageIds = new Set(state.orders.filter((order) => order.status === 'paid').map((order) => order.packageId))
  const [expertsOpen, setExpertsOpen] = useState(false)
  return <div className="page-stack services-page"><button className="back-button services-back" onClick={() => navigate(-1)}>返回</button>
    <div className="service-direction-tabs" role="tablist" aria-label="专家支持方向">
      <button role="tab" aria-selected="true" className="active"><span>泌乳支持</span><small>{lactationPackages.length} 个方案</small></button>
      <button role="tab" aria-selected="false" disabled><span>产后康复</span><small>陆续开放</small></button>
    </div>
    <ServiceExpertTeam onViewTeam={() => setExpertsOpen(true)} />
    <div className="package-list">{lactationPackages.map((pkg) => {
      const purchased = purchasedPackageIds.has(pkg.id)
      return <Card key={pkg.id} className={`package-card package-card-compact service-package-card ${purchased ? 'purchased' : ''}`}>
        <div className="package-top"><div className="package-title-block"><h2>{pkg.name}</h2></div><strong className="price">${pkg.price}<small> USD</small></strong></div>
        <p className="package-goal">{pkg.description}</p>
        <div className="package-expert-support"><Icon name="users" /><span>真人 IBCLC 专家支持</span><span className="package-inline-divider" aria-hidden="true" /><span className="package-consultation-count">{pkg.sessions} 次 IBCLC 在线咨询</span></div>
        <div className="package-daily-followup"><Icon name="calendar" /><span className="package-duration">{pkg.durationDays} 天</span><span className="package-inline-divider" aria-hidden="true" /><span className="package-daily-copy">{packageDailyFollowupCopy}</span></div>
        <div className="package-actions">{purchased ? <Button size="sm" variant="soft" disabled aria-label={`${pkg.name}已购买`}>已购买</Button> : <Button size="sm" variant="soft" onClick={() => navigate(`/app/services/${pkg.id}`)}>查看方案 <Icon name="arrow" /></Button>}</div>
      </Card>
    })}</div>
    {expertsOpen && <ServiceExpertTeamModal onClose={() => setExpertsOpen(false)} />}
  </div>
}

type PurchaseStep = 'closed' | 'eligibility' | 'payment'
type StripePaymentStatus = 'idle' | 'processing' | 'requires_action' | 'failed' | 'reconciling' | 'succeeded'

function formatCardNumber(value: string) {
  return value.replace(/\D/g, '').slice(0, 16).replace(/(.{4})/g, '$1 ').trim()
}

function formatExpiry(value: string) {
  const digits = value.replace(/\D/g, '').slice(0, 4)
  return digits.length > 2 ? `${digits.slice(0, 2)}/${digits.slice(2)}` : digits
}

function ServiceDetailPage({ initialPurchaseStep = 'closed' }: { initialPurchaseStep?: PurchaseStep }) {
  const { state, selectedPackage, dispatch, booking } = useProduct()
  const { packageId } = useParams()
  const packageItem = state.packages.find((item) => item.id === packageId) ?? selectedPackage
  const navigate = useNavigate()
  const [purchaseStep, setPurchaseStep] = useState<PurchaseStep>(initialPurchaseStep)
  const [location, setLocation] = useState(state.user.state)
  const [accepted, setAccepted] = useState(false)
  const [cardNumber, setCardNumber] = useState('4242 4242 4242 4242')
  const [expiry, setExpiry] = useState('12/34')
  const [cvc, setCvc] = useState('123')
  const [postalCode, setPostalCode] = useState('94107')
  const [paymentStatus, setPaymentStatus] = useState<StripePaymentStatus>('idle')
  const paymentTimer = useRef<number | undefined>(undefined)
  const idempotencyKey = useRef(`stripe-demo-${packageItem.id}-${Date.now()}`)
  const locationSupported = location === state.user.state
  const canContinue = locationSupported && accepted
  const purchasedOrder = state.orders.find((order) => order.status === 'paid' && order.packageId === packageItem.id)
  const purchasedEpisode = purchasedOrder ? state.episodes.find((episode) => episode.orderId === purchasedOrder.id) : undefined
  const existingPaid = Boolean(purchasedOrder && purchasedEpisode)
  const [expertsOpen, setExpertsOpen] = useState(false)
  const bookingPath = '/app/appointment'
  const paymentReady = cardNumber.replace(/\D/g, '').length === 16 && expiry.replace(/\D/g, '').length === 4 && cvc.length >= 3 && postalCode.trim().length >= 3

  useEffect(() => () => {
    if (paymentTimer.current !== undefined) window.clearTimeout(paymentTimer.current)
  }, [])

  const schedulePaymentUpdate = (callback: () => void, delay = 700) => {
    if (paymentTimer.current !== undefined) window.clearTimeout(paymentTimer.current)
    paymentTimer.current = window.setTimeout(callback, delay)
  }
  const closePurchase = () => {
    const purchaseSucceeded = paymentStatus === 'succeeded'
    if (paymentTimer.current !== undefined) window.clearTimeout(paymentTimer.current)
    setPurchaseStep('closed')
    setLocation(state.user.state)
    setAccepted(false)
    setPaymentStatus('idle')
    if (purchaseSucceeded) {
      navigate('/app/home', { replace: true })
      return
    }
    if (initialPurchaseStep !== 'closed') navigate(`/app/services/${packageItem.id}`, { replace: true })
  }
  const startBooking = () => {
    dispatch({ type: 'activateService', packageId: packageItem.id })
    navigate(bookingPath)
  }
  const continueToPayment = () => {
    if (!canContinue) return
    dispatch({ type: 'selectPackage', packageId: packageItem.id })
    setPurchaseStep('payment')
  }
  const finalizePayment = () => {
    void booking.completeDemoPurchase().then((saved) => setPaymentStatus(saved ? 'succeeded' : 'reconciling'))
  }
  const completePayment = () => {
    dispatch({ type: 'setOrderStatus', status: 'reconciling' })
    setPaymentStatus('reconciling')
    schedulePaymentUpdate(finalizePayment, 650)
  }
  const submitPayment = () => {
    if (!paymentReady || paymentStatus === 'processing') return
    const cardDigits = cardNumber.replace(/\D/g, '')
    dispatch({ type: 'selectPackage', packageId: packageItem.id })
    dispatch({ type: 'createOrder', idempotencyKey: idempotencyKey.current })
    setPaymentStatus('processing')
    schedulePaymentUpdate(() => {
      if (cardDigits === '4000000000009995') {
        dispatch({ type: 'setOrderStatus', status: 'failed' })
        setPaymentStatus('failed')
        return
      }
      if (cardDigits === '4000002500003155') {
        setPaymentStatus('requires_action')
        return
      }
      completePayment()
    })
  }
  const confirmThreeDSecure = () => {
    setPaymentStatus('processing')
    schedulePaymentUpdate(completePayment)
  }
  const reconcilePayment = () => {
    setPaymentStatus('processing')
    schedulePaymentUpdate(finalizePayment)
  }
  return <div className="page-stack service-detail-page">
    <header className="service-detail-header">
      <div className="service-detail-nav"><button className="back-button" onClick={() => navigate(-1)}>返回</button><h1>{packageItem.name}服务包</h1></div>
    </header>
    <ServiceExpertTeam compact onViewTeam={() => setExpertsOpen(true)} />
    <Card className="service-overview-card">
      <p className="service-overview-copy">{packageItem.description}</p>
      <div className="package-expert-support"><Icon name="users" /><span>真人 IBCLC 专家支持</span><span className="package-inline-divider" aria-hidden="true" /><span className="package-consultation-count">{packageItem.sessions} 次 IBCLC 在线咨询</span></div>
      <div className="package-daily-followup"><Icon name="calendar" /><span className="package-duration">{packageItem.durationDays} 天</span><span className="package-inline-divider" aria-hidden="true" /><span className="package-daily-copy">{packageDailyFollowupCopy}</span></div>
    </Card>
    <section className="service-delivery-section" aria-label={`${packageItem.expertRole} 服务`}><SectionTitle title={`${packageItem.expertRole} 服务`} /><div className="service-detail-list">{packageItem.expertServices.map((item) => <div key={item}><Icon name="video" /><span>{item}</span></div>)}</div></section>
    <section className="service-delivery-section" aria-label="AI / App 持续服务"><SectionTitle title="AI / App 持续服务" /><div className="service-detail-list continuous">{packageItem.continuousServices.map((item) => <div key={item}><Icon name="check" /><span>{item}</span></div>)}</div></section>
    <div className="sticky-cta"><div><strong>${packageItem.price}</strong></div><Button size="lg" onClick={existingPaid ? startBooking : () => setPurchaseStep('eligibility')}>{existingPaid ? '开始预约' : '购买'}</Button></div>
    {expertsOpen && <ServiceExpertTeamModal onClose={() => setExpertsOpen(false)} />}
    {purchaseStep === 'eligibility' && <Modal title="购买前确认" className="eligibility-modal" onClose={closePurchase}>
      <div className="eligibility-modal-form">
        <div className="eligibility-modal-package"><span>当前方案</span><strong>{packageItem.name}服务包 · ${packageItem.price}</strong></div>
        <label className="eligibility-field" htmlFor="eligibility-location"><span>当前所在州</span><select id="eligibility-location" value={location} onChange={(event) => setLocation(event.target.value)}><option value="CA">California (CA)</option><option value="NY">New York (NY)</option><option value="TX">Texas (TX)</option></select></label>
        {!locationSupported && <div className="inline-warning" role="alert"><Icon name="shield" /><span>当前服务暂未覆盖该州</span></div>}
        <label className="check-row eligibility-confirm"><input type="checkbox" checked={accepted} onChange={(event) => setAccepted(event.target.checked)} /><span>我确认所在州正确，并了解这不是紧急医疗服务。</span></label>
        <Button size="lg" disabled={!canContinue} onClick={continueToPayment}>确认并继续</Button>
      </div>
    </Modal>}
    {purchaseStep === 'payment' && <Modal title="安全支付" className="payment-modal" onClose={closePurchase}>
      <div className="stripe-payment-form">
        <div className="stripe-test-banner"><Badge tone="green">测试模式</Badge><span>Stripe 模拟支付，不会产生真实扣款</span></div>
        <div className="stripe-order-summary"><div><span>购买方案</span><strong>{packageItem.name}服务包</strong></div><strong>${packageItem.price}</strong></div>
        {paymentStatus !== 'succeeded' && <section className="stripe-payment-element" aria-labelledby="stripe-card-heading">
          <div className="stripe-element-heading"><div><Icon name="lock" /><strong id="stripe-card-heading">银行卡</strong></div><span>由 Stripe 安全处理</span></div>
          <label className="stripe-field stripe-card-field"><span>卡号</span><div><input aria-label="卡号" inputMode="numeric" autoComplete="cc-number" value={cardNumber} onChange={(event) => { setCardNumber(formatCardNumber(event.target.value)); setPaymentStatus('idle') }} /><em>卡</em></div></label>
          <div className="stripe-field-row">
            <label className="stripe-field"><span>有效期</span><input aria-label="有效期" inputMode="numeric" autoComplete="cc-exp" placeholder="MM/YY" value={expiry} onChange={(event) => setExpiry(formatExpiry(event.target.value))} /></label>
            <label className="stripe-field"><span>安全码</span><input aria-label="安全码" inputMode="numeric" autoComplete="cc-csc" value={cvc} onChange={(event) => setCvc(event.target.value.replace(/\D/g, '').slice(0, 4))} /></label>
          </div>
          <label className="stripe-field"><span>账单邮编</span><input aria-label="账单邮编" inputMode="numeric" autoComplete="postal-code" value={postalCode} onChange={(event) => setPostalCode(event.target.value.slice(0, 10))} /></label>
        </section>}

        {paymentStatus === 'failed' && <div className="stripe-status stripe-status-error" role="alert"><Icon name="clock" /><div><strong>付款未完成</strong><span>测试卡被拒绝，没有创建服务权益。你可以更换卡片后重试。</span></div></div>}
        {paymentStatus === 'reconciling' && <div className="stripe-status stripe-status-warning" role="status"><Icon name="clock" /><div><strong>正在确认付款结果</strong><span>服务端正在向 Stripe 确认结果，请勿重复支付。</span></div><Button size="sm" variant="soft" onClick={reconcilePayment}>查询结果</Button></div>}
        {paymentStatus === 'requires_action' && <div className="stripe-auth-panel" role="alertdialog" aria-label="3D Secure 验证"><div className="stripe-auth-mark"><Icon name="shield" /></div><div><strong>银行需要验证此付款</strong><span>模拟 Stripe 3D Secure 挑战。完成验证后才会确认付款。</span></div><div className="stripe-auth-actions"><button className="text-button" onClick={() => setPaymentStatus('idle')}>返回支付</button><Button size="sm" onClick={confirmThreeDSecure}>完成验证</Button></div></div>}
        {booking.error && <div role="alert" className="inline-warning">{booking.error}</div>}
        {paymentStatus === 'succeeded' && <div className="stripe-status stripe-status-success" role="status"><Icon name="check" /><div><strong>购买成功</strong><span>服务包已加入你的账户，可以现在或稍后开始预约。</span></div></div>}

        {paymentStatus !== 'requires_action' && paymentStatus !== 'reconciling' && paymentStatus !== 'succeeded' && <Button size="lg" disabled={!paymentReady || paymentStatus === 'processing'} onClick={submitPayment}>{paymentStatus === 'processing' ? '正在提交…' : `支付 $${packageItem.price}`}</Button>}
        {paymentStatus === 'succeeded' && <Button size="lg" onClick={startBooking}>开始预约</Button>}
        {paymentStatus !== 'succeeded' && <p className="stripe-legal-note">提交即表示你同意购买该服务包。付款由 Stripe 处理。</p>}
      </div>
    </Modal>}
  </div>
}

function IntakePage() {
  const { state, dispatch, consultation } = useProduct()
  const navigate = useNavigate()
  const [goal, setGoal] = useState(state.intake.feedingGoal)
  const [support, setSupport] = useState(state.intake.supportNeeded)
  const [consent, setConsent] = useState(state.consent.scopes.includes('ibclc_case') && state.consent.scopes.includes('video'))
  const [showConsentInfo, setShowConsentInfo] = useState(false)
  const [preconsultTarget, setPreconsultTarget] = useState<{ packageId: string; packageName: string; appointment: Appointment }>()
  const [selectedSymptoms, setSelectedSymptoms] = useState(state.intake.symptoms)
  const [currentState, setCurrentState] = useState(state.bookingPrecheck.state || state.user.state)
  const [postpartumDay, setPostpartumDay] = useState(String(state.user.postpartumDay))
  const [babyName, setBabyName] = useState(state.baby.name)
  const [babyBirthDate, setBabyBirthDate] = useState(state.baby.birthDate)
  const [babySex, setBabySex] = useState<BabySex>(state.baby.sex)
  const [feedingMode, setFeedingMode] = useState(state.baby.feedingMode)
  const computedBabyAgeLabel = babyAgeLabel(babyBirthDate)
  const computedPostpartumStage = postpartumDay.trim() ? postpartumStageForDay(Number(postpartumDay)) : undefined
  const profileReady = Boolean(currentState && postpartumDay.trim() && Number(postpartumDay) >= 0 && babyName.trim() && babyBirthDate && babyBirthDate <= localDateKey() && babySex !== 'unspecified' && feedingMode)
  const ready = selectedSymptoms.length > 0 && goal.trim().length > 0 && consent && profileReady
  const appointmentReady = state.appointment?.status === 'confirmed' || state.appointment?.status === 'in_progress'
  const leaveIntake = () => {
    if (appointmentReady) navigate('/app/home')
    else navigate(-1)
  }
  const submit = async () => {
    if (!ready || consultation.busy || !state.appointment) return
    const appointment = state.appointment
    const episode = state.episodes.find((item) => item.id === appointment.episodeId)
    const firstSubmission = !(appointment.intakeSubmitted ?? episode?.intakeSubmitted)
    const order = state.orders.find((item) => item.id === episode?.orderId)
    const packageItem = state.packages.find((item) => item.id === order?.packageId)
    const scopes = new Set(state.consent.scopes)
    scopes.add('app_service')
    scopes.add('ibclc_case')
    scopes.add('video')
    if (state.appointment && consultation.mode === 'server') {
      const submitted = await consultation.submitIntake(state.appointment.id, {
        symptoms: selectedSymptoms,
        feedingGoal: goal.trim(),
        supportNeeded: support.trim(),
        riskLevel: state.intake.riskLevel,
        profile: {
          stateCode: currentState,
          postpartumDay: Number(postpartumDay),
          babyName: babyName.trim(),
          babyAgeLabel: computedBabyAgeLabel,
          feedingMode,
        },
        consentVersion: state.consent.version,
      })
      if (!submitted) return
    }
    dispatch({ type: 'submitIntake', symptoms: selectedSymptoms, feedingGoal: goal.trim(), supportNeeded: support.trim(), riskLevel: state.intake.riskLevel, profile: { state: currentState, postpartumDay: Number(postpartumDay), babyName: babyName.trim(), babyBirthDate, babySex, babyAgeLabel: computedBabyAgeLabel, feedingMode } })
    dispatch({ type: 'setConsent', status: 'active', scopes: [...scopes] })
    if (firstSubmission && packageItem) {
      setPreconsultTarget({ packageId: packageItem.id, packageName: packageItem.name, appointment })
    } else {
      navigate(`/app/appointments/${appointment.id}`)
    }
  }
  if (!appointmentReady) return <div className="page-stack intake-page"><header className="service-detail-nav intake-page-header"><button className="back-button" onClick={leaveIntake}>返回</button><h1>信息采集表</h1></header><EmptyState title="请先确认预约时间" body="信息采集表会与已确认的首次咨询关联。" action={<Button onClick={() => navigate('/app/appointment')}>选择时间</Button>} /></div>
  return <div className="page-stack intake-page">
    <header className="service-detail-nav intake-page-header"><button className="back-button" onClick={leaveIntake}>返回</button><h1>信息采集表</h1></header>
    <Card className="form-card intake-core-card">
      <div className="intake-question-heading" id="intake-symptoms-label"><strong>这次最想解决什么？</strong><span>可多选</span></div>
      <div className="choice-grid" role="group" aria-labelledby="intake-symptoms-label">{['含乳困难', '喂养疼痛', '奶量担心', '宝宝频繁醒来', '泵奶安排', '其他'].map((item) => <button type="button" key={item} aria-pressed={selectedSymptoms.includes(item)} className={selectedSymptoms.includes(item) ? 'choice selected' : 'choice'} onClick={() => setSelectedSymptoms((current) => current.includes(item) ? current.filter((value) => value !== item) : [...current, item])}>{item}{selectedSymptoms.includes(item) && <Icon name="check" />}</button>)}</div>
      <label htmlFor="intake-goal">希望咨询后有什么变化？</label>
      <textarea id="intake-goal" value={goal} onChange={(event) => setGoal(event.target.value)} rows={2} placeholder="例如：减少含乳疼痛，找到合适的喂养节奏" />
      <details className="intake-optional"><summary><span>补充情况</span><span>{support.trim() ? '已填写' : '可选'}</span><span className="details-chevron">⌄</span></summary><p>可以补充近期体重、黄疸、用药，或近 24 小时喂养与泵奶情况。</p><label htmlFor="intake-support">还想让 IBCLC 知道什么？</label><textarea id="intake-support" value={support} onChange={(event) => setSupport(event.target.value)} rows={3} /></details>
    </Card>
    <details className="intake-profile-disclosure">
      <summary><strong>基础信息</strong><span>{profileReady ? '已预填，可修改' : '需完善'}</span><span className="details-chevron">⌄</span></summary>
      <div className="intake-prefill-grid">
        <label className="intake-prefill-field"><span>当前所在州</span><select value={currentState} onChange={(event) => setCurrentState(event.target.value)}><option value="CA">California (CA)</option><option value="NY">New York (NY)</option><option value="TX">Texas (TX)</option></select></label>
        <label className="intake-prefill-field"><span>产后天数{computedPostpartumStage ? ` · ${computedPostpartumStage.label}` : ''}</span><input type="number" min="0" inputMode="numeric" value={postpartumDay} onChange={(event) => setPostpartumDay(event.target.value)} /></label>
        <label className="intake-prefill-field"><span>宝宝称呼</span><input value={babyName} onChange={(event) => setBabyName(event.target.value)} /></label>
        <label className="intake-prefill-field"><span>宝宝出生日期</span><input type="date" max={localDateKey()} value={babyBirthDate} onChange={(event) => setBabyBirthDate(event.target.value)} /></label>
        <label className="intake-prefill-field"><span>出生记录性别</span><select value={babySex} onChange={(event) => setBabySex(event.target.value as BabySex)}><option value="unspecified" disabled>请选择</option><option value="female">女宝宝</option><option value="male">男宝宝</option></select></label>
        <div className="intake-prefill-field"><span>宝宝月龄</span><strong className="intake-derived-value">{computedBabyAgeLabel}</strong></div>
        <label className="intake-prefill-field intake-prefill-wide"><span>当前喂养方式</span><select value={feedingMode} onChange={(event) => setFeedingMode(event.target.value)}><option value="纯母乳">纯母乳</option><option value="母乳 + 瓶喂">母乳 + 瓶喂</option><option value="配方奶">配方奶</option><option value="混合喂养">混合喂养</option></select></label>
      </div>
    </details>
    <section className="intake-consent-card" aria-labelledby="intake-consent-title"><div className="intake-consent-heading"><div className="intake-consent-icon"><Icon name="lock" /></div><div><h2 id="intake-consent-title">信息使用</h2></div><button className="text-button" onClick={() => setShowConsentInfo(true)}>查看说明</button></div><label className="check-row required"><input type="checkbox" checked={consent} onChange={(event) => setConsent(event.target.checked)} /><span>允许本次服务的 IBCLC 查看此表</span></label></section>
    {consultation.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{consultation.error}</span></div>}<Button className="intake-submit" size="lg" disabled={!ready || consultation.busy} onClick={() => { void submit() }}>{consultation.busy ? '正在保存…' : state.episode?.intakeSubmitted ? '保存修改' : '保存信息'}</Button>
    {showConsentInfo && <Modal title="信息使用说明" className="intake-consent-modal" onClose={() => setShowConsentInfo(false)}><div className="intake-consent-modal-body"><div className="intake-consent-scope"><span>提供给谁</span><strong>本次服务的 IBCLC</strong></div><div className="intake-consent-scope"><span>包含什么</span><strong>本页填写内容与确认后的基础信息</strong></div><div className="intake-consent-scope"><span>用于什么</span><strong>咨询前了解情况与准备咨询</strong></div><Button size="lg" onClick={() => setShowConsentInfo(false)}>知道了</Button></div></Modal>}
    {preconsultTarget && <Modal title="信息采集已完成" className="booking-success-modal" showClose={false} onClose={() => navigate(`/app/appointments/${preconsultTarget.appointment.id}`)}><div className="booking-success-content"><div className="booking-success-mark"><Icon name="check" /></div><div className="booking-success-appointment"><strong>{formatAppointmentDay(preconsultTarget.appointment.start, preconsultTarget.appointment.timezone)} · {formatAppointmentRange(preconsultTarget.appointment.start, preconsultTarget.appointment.end, preconsultTarget.appointment.timezone)}</strong><AssignedExpertIdentity expertId={preconsultTarget.appointment.ibclcId} expertName={preconsultTarget.appointment.ibclcName} label="本次咨询专家" /></div><p>Cozymate 会结合“{preconsultTarget.packageName}”和你填写的信息，进一步了解本次咨询重点，并将重点同步给 IBCLC。</p><div className="booking-success-actions"><Button size="lg" onClick={() => navigate(agentPreconsultPath(preconsultTarget.packageId))}>开始预问诊</Button><button className="text-button booking-later-action" onClick={() => navigate(`/app/appointments/${preconsultTarget.appointment.id}`)}>稍后再说，查看预约</button></div></div></Modal>}
  </div>
}

function AppointmentPage() {
  const { state, selectedPackage, consultation, booking } = useProduct()
  const navigate = useNavigate()
  const location = useLocation()
  const savedPrecheck = state.bookingPrecheck.episodeId === state.episode?.id ? state.bookingPrecheck : undefined
  const hasBookableSessions = Boolean(state.episode && state.episode.remainingSessions > 0)
  const precheckReady = Boolean(
    savedPrecheck?.completedAt
    && savedPrecheck.state === 'CA'
    && savedPrecheck.serviceSuitable
    && savedPrecheck.emergencyStatus === 'clear'
    && (booking.mode === 'browser_mock' || (
      savedPrecheck.eligibilityCheckId
      && savedPrecheck.expiresAt
      && new Date(savedPrecheck.expiresAt).getTime() > Date.now()
    )),
  )
  const [precheckOpen, setPrecheckOpen] = useState(hasBookableSessions && !precheckReady)
  const [precheckLocation, setPrecheckLocation] = useState(savedPrecheck?.state || state.user.state)
  const [serviceSuitable, setServiceSuitable] = useState(savedPrecheck?.serviceSuitable ?? false)
  const [emergencyStatus, setEmergencyStatus] = useState<'unchecked' | 'clear' | 'needs_help'>(savedPrecheck?.emergencyStatus ?? 'unchecked')
  const [showSelectionConfirm, setShowSelectionConfirm] = useState(state.appointment?.status === 'held')
  const [cancelPending, setCancelPending] = useState(false)
  const locationSupported = precheckLocation === 'CA'
  const canCompletePrecheck = locationSupported && serviceSuitable && emergencyStatus === 'clear'
  const dateKey = (date: Date) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
  const today = dateKey(new Date())
  const appointmentExperts = useMemo(() => booking.providers.map((item) => ({
    id: item.id,
    name: item.name,
  })), [booking.providers])
  const recommendedExpertId = new URLSearchParams(location.search).get('ibclc') ?? ''
  const activeAppointmentSlot = state.appointment && state.appointment.status !== 'cancelled'
    ? booking.availability.find((slot) => slot.start === state.appointment?.start && slot.ibclcId === state.appointment?.ibclcId)
    : undefined
  const currentAppointment = state.appointment
  const appointmentDate = currentAppointment && currentAppointment.status !== 'cancelled'
    ? appointmentDateKey(currentAppointment.start, currentAppointment.timezone)
    : undefined
  const initialDate = appointmentDate && appointmentDate >= today ? appointmentDate : today
  const [selectedDate, setSelectedDate] = useState(initialDate)
  const [selectedExpert, setSelectedExpert] = useState(
    appointmentExperts.some((item) => item.id === recommendedExpertId)
      ? recommendedExpertId
      : activeAppointmentSlot?.ibclcId ?? state.appointment?.ibclcId ?? appointmentExperts[0]?.id ?? '',
  )
  const selectedExpertName = appointmentExperts.find((item) => item.id === selectedExpert)?.name
  const selectedExpertProfile = serviceExpertProfileFor(selectedExpert, selectedExpertName)
  const [selected, setSelected] = useState<string | undefined>(activeAppointmentSlot?.id)
  const selectedSlot = state.appointment
  const canBook = hasBookableSessions && precheckReady
  const appointmentConfirmed = selectedSlot?.status === 'confirmed' || selectedSlot?.status === 'in_progress'
  const rebookingAfterAttendance = Boolean(selectedSlot?.attendanceOutcome)
  const rebookingAfterCompletedConsultation = selectedSlot?.status === 'completed' && hasBookableSessions
  const visibleSlots = useMemo(() => {
    const expert = appointmentExperts.find((item) => item.id === selectedExpert)
    if (!expert) return []
    if (booking.mode === 'server') {
      return booking.availability.filter((slot) => (
        slot.ibclcId === selectedExpert
        && appointmentDateKey(slot.start, slot.timezone) === selectedDate
      ))
    }
    const now = Date.now()
    return [9, 10, 11, 13, 14, 15, 16].map((hour): AvailabilitySlot => {
      const hourLabel = String(hour).padStart(2, '0')
      const nextHourLabel = String(hour + 1).padStart(2, '0')
      const start = `${selectedDate}T${hourLabel}:00:00`
      const persistedSlot = booking.availability.find((slot) => slot.start === start && slot.ibclcId === expert.id)
      const occupied = state.appointments.some((appointment) => appointment.start === start && appointment.ibclcName === expert.name && appointment.status !== 'cancelled')
      return persistedSlot ?? {
        id: `slot-${selectedDate}-${expert.id}-${hourLabel}`,
        start,
        end: `${selectedDate}T${nextHourLabel}:00:00`,
        timezone: state.user.timezone,
        ibclcId: expert.id,
        ibclcName: expert.name,
        held: occupied || undefined
      }
    }).map((slot) => state.appointments.some((appointment) => appointment.start === slot.start && appointment.ibclcName === slot.ibclcName && appointment.status !== 'cancelled') ? { ...slot, held: true } : slot)
      .filter((slot) => selectedDate !== today || new Date(slot.start).getTime() > now)
  }, [appointmentExperts, booking.availability, booking.mode, selectedDate, selectedExpert, state.appointments, state.user.timezone, today])
  useEffect(() => {
    if (!precheckReady || booking.mode !== 'server' || !savedPrecheck?.eligibilityCheckId) return
    void booking.loadAvailability({
      eligibilityCheckId: savedPrecheck.eligibilityCheckId,
      dateFrom: selectedDate,
      dateTo: selectedDate,
    })
  }, [booking.mode, precheckReady, savedPrecheck?.eligibilityCheckId, selectedDate])
  useEffect(() => {
    if (!selectedExpert && appointmentExperts[0]) setSelectedExpert(appointmentExperts[0].id)
  }, [appointmentExperts, selectedExpert])
  useEffect(() => {
    if (state.appointment?.status !== 'held') return
    const matching = booking.availability.find((slot) => (
      slot.start === state.appointment?.start && slot.ibclcId === state.appointment?.ibclcId
    ))
    if (matching) setSelected(matching.id)
  }, [booking.availability, state.appointment?.id, state.appointment?.status])
  const changeDate = async (date: string) => {
    if (!date || date < today || date === selectedDate) return
    await booking.release()
    setSelected(undefined)
    setShowSelectionConfirm(false)
    setSelectedDate(date)
  }
  const changeExpert = async (expertId: string) => {
    if (expertId === selectedExpert) return
    await booking.release()
    setSelected(undefined)
    setShowSelectionConfirm(false)
    setSelectedExpert(expertId)
  }
  const completePrecheck = async () => {
    if (!state.episode || !canCompletePrecheck) return
    const completed = await booking.checkEligibility({
      stateCode: precheckLocation,
      serviceSuitable,
      emergencyStatus,
    })
    if (completed) setPrecheckOpen(false)
  }
  const confirm = async () => {
    if (!canBook || selectedSlot?.status !== 'held') return
    const confirmed = await booking.confirm()
    if (!confirmed) return
    setShowSelectionConfirm(false)
    navigate('/app/intake', { replace: true })
  }
  const cancelAppointment = async () => {
    if (!selectedSlot) return
    const cancelled = await consultation.cancel(selectedSlot.id)
    if (!cancelled) return
    setCancelPending(false)
    navigate('/app/home')
  }
  const leaveAppointment = () => {
    if (appointmentConfirmed) navigate('/app/home')
    else navigate(-1)
  }
  const formatWeekday = (value: string) => new Intl.DateTimeFormat('zh-CN', { weekday: 'short' }).format(new Date(`${value}T12:00:00`))
  return <div className="page-stack appointment-page">
    <header className="service-detail-nav appointment-page-header"><button className="back-button" onClick={leaveAppointment}>返回</button><h1>{appointmentConfirmed ? '预约详情' : '选择时间'}</h1></header>
    {!state.episode && <div className="inline-warning"><Icon name="lock" /><span>先完成服务购买</span><button className="text-button" onClick={() => navigate('/app/services')}>去购买</button></div>}
    {state.episode && !hasBookableSessions && !appointmentConfirmed && <Card className="booking-entitlement-exhausted"><span className="booking-entitlement-icon"><Icon name="check" /></span><div><strong>咨询权益已用完</strong><p>本服务包的在线咨询次数已使用完，暂不支持继续预约。</p></div></Card>}
    {state.episode && hasBookableSessions && precheckReady && !appointmentConfirmed && (selectedSlot?.status !== 'completed' || rebookingAfterAttendance || rebookingAfterCompletedConsultation) && <>
    <section className="appointment-picker" aria-label="筛选可预约时间">
      <label className="appointment-date-field"><span>日期</span><div className="appointment-date-control"><input type="date" min={today} value={selectedDate} onInput={(event) => { const input = event.currentTarget; if (input.value && input.value < today) input.value = today; changeDate(input.value) }} aria-label="选择预约日期" /><small>{selectedDate === today ? '今天 · ' : ''}{formatWeekday(selectedDate)}</small></div></label>
      <div className="appointment-expert-preview"><ExpertAvatar expertId={selectedExpert} expertName={selectedExpertName} /><div><span>可预约专家</span><strong>{selectedExpertProfile.name}<small>{selectedExpertProfile.credential}</small></strong><em>{selectedExpertProfile.focus}</em></div></div>
      <label className="appointment-expert-field"><span>选择专家</span><select value={selectedExpert} disabled={booking.busy || !appointmentExperts.length} onChange={(event) => { void changeExpert(event.target.value) }}>{appointmentExperts.map((expert) => <option key={expert.id} value={expert.id}>{expert.name}</option>)}</select></label>
    </section>
    <div className="slot-list-heading"><h2>可选时间</h2><span>{visibleSlots.length} 个时段</span></div>
    {booking.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{booking.error}</span></div>}
    {visibleSlots.length ? <div className="slot-list">{visibleSlots.map((slot) => {
      const unavailable = Boolean(slot.held && selected !== slot.id)
      return <button key={slot.id} className={`slot-card ${selected === slot.id ? 'selected' : ''} ${unavailable ? 'disabled' : ''}`} disabled={!canBook || unavailable || booking.busy} onClick={() => { void (async () => { booking.clearError(); setSelected(slot.id); const held = await booking.hold(slot); if (!held) { setSelected(undefined); return } setShowSelectionConfirm(true) })() }}><div className="appointment-slot-copy"><strong>{formatAppointmentRange(slot.start, slot.end, slot.timezone)}</strong><span>{getAppointmentMinutes(slot.start, slot.end)} 分钟{unavailable ? ' · 已占用' : ''}</span></div><span className="slot-radio">{selected === slot.id ? <Icon name="check" /> : ''}</span></button>
    })}</div> : <div className="appointment-empty"><strong>{selectedDate === today ? '今天已无可预约时间' : '暂无可选时间'}</strong><span>请尝试其他日期或专家。</span></div>}
    </>}
    {state.episode && precheckReady && appointmentConfirmed && selectedSlot && <Card className="appointment-detail-card"><div className="appointment-detail-time"><span className="appointment-detail-icon"><Icon name="calendar" /></span><div><span className="appointment-detail-context">{selectedSlot.serviceName ?? selectedPackage.name} · 首次咨询</span><strong>{formatAppointmentDay(selectedSlot.start, selectedSlot.timezone)} · {formatAppointmentRange(selectedSlot.start, selectedSlot.end, selectedSlot.timezone)}</strong></div></div><AssignedExpertIdentity expertId={selectedSlot.ibclcId} expertName={selectedSlot.ibclcName} />{selectedSlot.status === 'confirmed' && <div className="appointment-detail-actions"><Button size="md" variant="danger" onClick={() => { consultation.clearError(); setCancelPending(true) }}>取消预约</Button></div>}</Card>}
    {precheckOpen && <Modal title="预约前确认" className="booking-precheck-modal" onClose={() => setPrecheckOpen(false)}><div className="booking-precheck-form">
      <label className="eligibility-field" htmlFor="booking-location"><span>当前所在州</span><select id="booking-location" value={precheckLocation} onChange={(event) => setPrecheckLocation(event.target.value)}><option value="CA">California (CA)</option><option value="NY">New York (NY)</option><option value="TX">Texas (TX)</option></select></label>
      {!locationSupported && <div className="inline-warning" role="alert"><Icon name="shield" /><span>当前 Demo 的 IBCLC 服务仅覆盖 California，暂不能继续预约。</span></div>}
      <fieldset className="booking-precheck-group"><legend>服务适用性</legend><label className="check-row"><input type="checkbox" checked={serviceSuitable} onChange={(event) => setServiceSuitable(event.target.checked)} /><span>我需要的是哺乳或喂养相关的 IBCLC 咨询，适用于“{selectedPackage.name}”服务包。</span></label></fieldset>
      <fieldset className="booking-precheck-group"><legend>紧急风险判断</legend><p>如妈妈或宝宝出现呼吸困难、无法唤醒、大量出血等情况，应先寻求紧急医疗帮助。</p><label className="booking-precheck-option"><input type="radio" name="booking-emergency" checked={emergencyStatus === 'clear'} onChange={() => setEmergencyStatus('clear')} /><span><strong>目前没有上述紧急情况</strong></span></label><label className="booking-precheck-option"><input type="radio" name="booking-emergency" checked={emergencyStatus === 'needs_help'} onChange={() => setEmergencyStatus('needs_help')} /><span><strong>有，或我不确定</strong></span></label></fieldset>
      {emergencyStatus === 'needs_help' && <div className="booking-emergency-warning" role="alert"><Icon name="shield" /><div><strong>请先寻求紧急帮助</strong><span>请联系 911 或当地急救服务；IBCLC 预约不能替代紧急医疗。</span></div></div>}
      {booking.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{booking.error}</span></div>}<Button size="lg" disabled={!canCompletePrecheck || booking.busy} onClick={() => { void completePrecheck() }}>{booking.busy ? '正在确认…' : '继续选择时间'}</Button>
    </div></Modal>}
    {showSelectionConfirm && selectedSlot?.status === 'held' && <Modal title="确认预约时间" className="booking-success-modal" onClose={() => setShowSelectionConfirm(false)}><div className="booking-success-content"><div className="booking-success-appointment"><strong>{formatAppointmentDay(selectedSlot.start, selectedSlot.timezone)} · {formatAppointmentRange(selectedSlot.start, selectedSlot.end, selectedSlot.timezone)}</strong><AssignedExpertIdentity expertId={selectedSlot.ibclcId} expertName={selectedSlot.ibclcName} label="本次可预约专家" /><span>{getAppointmentMinutes(selectedSlot.start, selectedSlot.end)} 分钟</span></div>{booking.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{booking.error}</span></div>}<Button size="lg" disabled={booking.busy} onClick={() => { void confirm() }}>{booking.busy ? '正在确认…' : '确认预约'}</Button><button className="text-button booking-later-action" disabled={booking.busy} onClick={() => { void (async () => { await booking.release(); setSelected(undefined); setShowSelectionConfirm(false) })() }}>重新选择</button></div></Modal>}
    {cancelPending && selectedSlot?.status === 'confirmed' && <Modal title="取消预约" className="booking-cancel-modal" showClose={!consultation.busy} onClose={() => { if (!consultation.busy) setCancelPending(false) }}><div className="booking-cancel-content"><div className="booking-cancel-summary"><span className="booking-cancel-icon"><Icon name="calendar" /></span><div><strong>{formatAppointmentDay(selectedSlot.start, selectedSlot.timezone)} · {formatAppointmentRange(selectedSlot.start, selectedSlot.end, selectedSlot.timezone)}</strong><AssignedExpertIdentity expertId={selectedSlot.ibclcId} expertName={selectedSlot.ibclcName} label="本次咨询专家" /></div></div><p>取消后，该时段将释放。重新预约时需要再次确认信息采集表，已填写内容会保留。</p>{consultation.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{consultation.error}</span></div>}<div className="booking-cancel-actions"><Button size="lg" disabled={consultation.busy} onClick={() => setCancelPending(false)}>保留预约</Button><Button size="lg" variant="danger" disabled={consultation.busy} onClick={() => { void cancelAppointment() }}>{consultation.busy ? '正在取消…' : '确认取消'}</Button></div></div></Modal>}
    {selectedSlot?.status === 'completed' && !rebookingAfterAttendance && !rebookingAfterCompletedConsultation && <Card className="success-banner"><Icon name="check" /><div><strong>咨询已完成</strong></div><Button size="sm" variant="soft" onClick={() => navigate('/app/summary')}>查看总结</Button></Card>}
  </div>
}

function ConsultPrepPage() {
  const { state } = useProduct()
  const navigate = useNavigate()
  useEffect(() => {
    const destination = !state.appointment || state.appointment.status === 'cancelled'
      ? '/app/appointment'
      : !state.episode?.intakeSubmitted
        ? '/app/intake'
        : `/app/appointments/${state.appointment.id}?start=1`
    navigate(destination, { replace: true })
  }, [navigate, state.appointment, state.episode?.intakeSubmitted])
  return null
}

function VideoPage() {
  const { state, selectedPackage, consultation } = useProduct()
  const [leavePending, setLeavePending] = useState(false)
  const joinedAppointmentRef = useRef<string | undefined>(undefined)
  const navigate = useNavigate()
  const { appointmentId: routeAppointmentId } = useParams()
  const appointment = consultationAppointmentForRoute(state, routeAppointmentId)
  const consentReady = state.consent.status === 'active' && state.consent.scopes.includes('video')
  const consultationSession = appointment ? state.consultationSessions.find((item) => item.consultation.appointmentId === appointment.id) : undefined
  const consultationState = consultationSession ? getConsultationDisplayState(consultationSession, 'user') : 'not_joined'
  const attendanceOutcome = consultationSession?.consultation.attendanceOutcome ?? appointment?.attendanceOutcome
  const rtc = useRtcMedia({
    credentials: consultationSession ? consultation.rtcCredentials[consultationSession.room.id] : undefined,
    onConnected: () => appointment ? consultation.mediaConnected(appointment.id, 'user') : undefined,
    onReconnecting: () => appointment ? consultation.markReconnecting(appointment.id, 'user') : undefined,
  })
  const networkNotice = rtcNetworkNotice(rtc.networkQuality)

  useEffect(() => {
    if (!appointment || !shouldHandOffConsultation(appointment.status, attendanceOutcome, consultationSession?.consultation.endReason)) return
    // Navigation unmounts the video view; disconnect explicitly before handoff.
    void rtc.disconnect()
    navigate(agentPostconsultPath(appointment.id), { replace: true })
  }, [appointment?.id, appointment?.status, attendanceOutcome, consultationSession?.consultation.endReason, navigate])

  useEffect(() => {
    if (!appointment || !consentReady || !appointment.locationVerified || (appointment.status !== 'confirmed' && appointment.status !== 'in_progress')) return
    if (joinedAppointmentRef.current === appointment.id) return
    joinedAppointmentRef.current = appointment.id
    void consultation.join(appointment.id, 'user')
  }, [appointment?.id, appointment?.locationVerified, appointment?.status, consentReady, consultation])
  useEffect(() => {
    if (rtc.isLiveKit || !appointment || (appointment.status !== 'confirmed' && appointment.status !== 'in_progress')) return
    const reconnecting = () => { void consultation.markReconnecting(appointment.id, 'user') }
    const reconnected = () => { void consultation.join(appointment.id, 'user') }
    window.addEventListener('offline', reconnecting)
    window.addEventListener('online', reconnected)
    return () => {
      window.removeEventListener('offline', reconnecting)
      window.removeEventListener('online', reconnected)
    }
  }, [appointment?.id, appointment?.status, consultation, rtc.isLiveKit])

  if (!appointment || appointment.status === 'cancelled') return <div className="page-stack"><PageIntro eyebrow="视频咨询" title="还没有预约" back /><EmptyState title="预约还未确认" body="先选时间。" action={<Button onClick={() => navigate('/app/appointment')}>去预约</Button>} /></div>
  const expertName = appointment.ibclcName
  const expertProfile = serviceExpertProfileFor(appointment.ibclcId, expertName)
  const leaveRoom = async () => {
    await rtc.disconnect()
    const left = await consultation.leave(appointment.id, 'user')
    if (!left) return
    setLeavePending(false)
    navigate('/app/home')
  }
  const header = <header className="service-detail-nav video-page-header"><button className="back-button" onClick={() => navigate('/app/home')}>返回</button><h1>视频咨询</h1></header>
  if (attendanceOutcome === 'user_no_show') return <div className="page-stack video-page">{header}<Card className="video-state-card consultation-outcome-card"><span className="video-state-icon"><Icon name="clock" /></span><h2>这次咨询未能开始</h2><p>我们没能在预约时间与你开始咨询。本次未扣减咨询次数，如需继续支持，可以重新预约。</p><Button onClick={() => navigate('/app/appointment')}>重新预约</Button><Button variant="ghost" onClick={() => navigate('/app/home')}>返回妈妈主页</Button></Card></div>
  if (attendanceOutcome === 'technical_failure') return <div className="page-stack video-page">{header}<Card className="video-state-card consultation-outcome-card"><span className="video-state-icon"><Icon name="wifi" /></span><h2>视频连接未能继续</h2><p>这不是你的问题。本次未扣减咨询次数，可以重新选择合适的时间。</p><Button onClick={() => navigate('/app/appointment')}>重新预约</Button><Button variant="ghost" onClick={() => navigate('/app/home')}>返回妈妈主页</Button></Card></div>
  if (!consentReady) return <div className="page-stack video-page">{header}<Card className="video-state-card"><span className="video-state-icon"><Icon name="lock" /></span><h2>需要恢复视频授权</h2><p>恢复授权后，再从妈妈主页开始本次咨询。</p><Button onClick={() => navigate('/app/privacy')}>去授权</Button></Card></div>
  if (appointment.status === 'completed' || consultationState === 'ended') return <div className="page-stack video-page">{header}<Card className="video-state-card"><span className="video-state-icon"><Icon name="check" /></span><h2>本次咨询已结束</h2><p>IBCLC 正在整理本次建议。</p><Button onClick={() => navigate(`/app/consultations/${appointment.id}/summary`)}>查看咨询总结</Button></Card></div>
  if (!appointment.locationVerified) return <div className="page-stack video-page">{header}<StartConsultModal initialLocation={state.bookingPrecheck.state || state.user.state} consentReady={consentReady} busy={consultation.busy} error={consultation.error} onClose={() => navigate('/app/home')} onRestoreConsent={() => navigate('/app/privacy')} onEnter={async (stateCode) => consultation.verifyLocationAndJoin(appointment.id, stateCode)} /></div>
  const expertConnected = consultationSession?.room.participants.ibclc.presence === 'joined'
  const active = consultationState === 'active'
  const roomCopy = consultationState === 'reconnecting'
    ? { title: '正在恢复连接', detail: '请保持此页开启，网络恢复后会自动重连' }
    : consultationState === 'ready_to_start'
    ? { title: `${expertName.replace(/,?\s*IBCLC$/i, '')} 已进入`, detail: '正在等待专家开始咨询' }
    : consultationState === 'expert_reconnecting'
      ? { title: '专家正在重新连接', detail: '请留在咨询室，不需要重新进入' }
      : consultationState === 'expert_left'
        ? { title: '专家暂时离开', detail: '咨询尚未结束，请稍候' }
        : { title: `等待 ${expertName.replace(/,?\s*IBCLC$/i, '')} 进入`, detail: '你已在咨询室中，可以保持此页开启' }
  return <div className="page-stack video-page">{header}{consultation.error && <div className="inline-warning" role="alert"><Icon name="bell" /><span>{consultation.error}</span></div>}<section className="video-room" aria-label={`与 ${expertName} 的视频咨询`}>
    <div className="video-session-summary"><div className="video-session-expert"><ExpertAvatar expertId={appointment.ibclcId} expertName={expertName} /><div><small>{expertProfile.name} · {expertProfile.credential}</small><strong>{formatAppointmentDay(appointment.start, appointment.timezone)} · {formatAppointmentRange(appointment.start, appointment.end, appointment.timezone)}</strong></div></div><Badge tone={active ? 'green' : 'blue'}>{active ? '咨询中' : consultationState === 'reconnecting' ? '重新连接' : '等待室'}</Badge></div>
    <div className={`video-call-stage ${active ? 'active' : 'waiting'}`} data-rtc-status={rtc.isLiveKit ? rtc.status : 'mock'}><span className="video-demo-pill">{rtc.isLiveKit ? `LiveKit · ${rtc.status === 'connected' ? '媒体已连接' : rtc.status === 'reconnecting' ? '正在重连' : '正在连接'}` : consultation.mode === 'server' ? '服务端状态 · Mock 视频' : 'Demo · 双端实时联动'}</span><video ref={rtc.remoteVideoRef} className={`rtc-remote-video ${rtc.remoteVideoAvailable && active ? 'visible' : ''}`} autoPlay playsInline data-testid="user-remote-video" /><audio ref={rtc.remoteAudioRef} autoPlay data-testid="user-remote-audio" />{active ? <>{!rtc.remoteVideoAvailable && <ExpertAvatar expertId={appointment.ibclcId} expertName={expertName} className="video-remote-avatar" />}<strong className="video-remote-name">{expertName}</strong><span className="video-connected"><StatusDot tone={(rtc.isLiveKit ? rtc.remoteParticipantConnected : expertConnected) ? 'green' : 'gray'} /> {(rtc.isLiveKit ? rtc.remoteParticipantConnected : expertConnected) ? '已连接' : '重新连接中'}</span></> : <div className="video-waiting-copy"><span className="video-waiting-pulse"><Icon name="video" /></span><strong>{roomCopy.title}</strong><p>{rtc.isLiveKit && rtc.status === 'connecting' ? '正在建立安全的视频连接' : roomCopy.detail}</p></div>}<div className={`video-self-view ${rtc.cameraOn ? '' : 'off'}`} aria-label={rtc.cameraOn ? '你的画面，摄像头已开启' : '你的画面，摄像头已关闭'}><video ref={rtc.localVideoRef} className={rtc.isLiveKit && rtc.cameraOn ? 'visible' : ''} autoPlay muted playsInline data-testid="user-local-video" /><span>{rtc.cameraOn ? state.user.name.slice(0, 1).toUpperCase() : <Icon name="video" />}</span><small>你</small></div></div>
    {rtc.error && <div className="video-media-warning" role="alert"><Icon name="wifi" /><span>{rtc.error}</span></div>}
    {networkNotice && <div className={`video-network-notice ${networkNotice.tone}`} aria-live="polite"><Icon name="wifi" /><span><strong>{networkNotice.title}</strong><small>{networkNotice.detail}</small></span></div>}
    {rtc.audioPlaybackBlocked && <button type="button" className="video-enable-audio" onClick={() => { void rtc.enableAudioPlayback() }}>点击开启通话声音</button>}
    <div className="video-controls" aria-label="视频咨询控制"><button type="button" className={`video-control ${rtc.microphoneOn ? '' : 'off'}`} aria-pressed={rtc.microphoneOn} disabled={rtc.mediaBusy} onClick={() => { void rtc.toggleMicrophone() }}><span className="video-control-icon"><Icon name="mic" /></span><span>{rtc.microphoneOn ? '麦克风' : '已静音'}</span></button><button type="button" className={`video-control ${rtc.cameraOn ? '' : 'off'}`} aria-pressed={rtc.cameraOn} disabled={rtc.mediaBusy} onClick={() => { void rtc.toggleCamera() }}><span className="video-control-icon"><Icon name="video" /></span><span>{rtc.cameraOn ? '摄像头' : '已关闭'}</span></button><button type="button" className="video-control leave" onClick={() => setLeavePending(true)}><span className="video-control-icon"><Icon name="arrow" /></span><span>离开房间</span></button></div>
  </section>{leavePending && <Modal title="暂时离开咨询室？" className="video-end-modal" onClose={() => setLeavePending(false)}><div className="video-end-content"><p>离开不会结束咨询，你可以从妈妈主页重新进入。</p><div className="video-end-actions"><Button size="lg" onClick={() => setLeavePending(false)}>留在房间</Button><Button size="lg" variant="soft" disabled={consultation.busy} onClick={() => { void leaveRoom() }}>{consultation.busy ? '正在离开…' : '暂时离开'}</Button></div></div></Modal>}</div>
}

function SummaryPage() {
  const { state, dispatch, selectedPackage, consultation, documentation } = useProduct()
  const navigate = useNavigate()
  const { appointmentId } = useParams()
  const appointment = appointmentId
    ? state.appointments.find((item) => item.id === appointmentId)
    : state.appointment
  const documentationRecord = appointment ? documentation.records[appointment.id] : undefined
  const publishedPlan = documentation.mode === 'server'
    ? documentationRecord?.currentPublication
    : state.carePlan?.status === 'published' ? state.carePlan : undefined
  const expertName = appointment?.ibclcName ?? 'IBCLC 专家'
  const expertShortName = expertName.replace(/,?\s*IBCLC$/i, '')
  const expertProfile = serviceExpertProfileFor(appointment?.ibclcId, expertName)
  const primaryTask = publishedPlan?.tasks.find((task) => task.status !== 'completed') ?? publishedPlan?.tasks[0]
  const nextTasks = publishedPlan?.tasks.filter((task) => task.id !== primaryTask?.id) ?? []
  const concernLabel = documentation.mode === 'server'
    ? (publishedPlan?.title ?? appointment?.serviceName ?? '本次咨询')
    : state.intake.supportNeeded || state.intake.symptoms.join('、') || '本次喂养问题'
  const serviceName = appointment?.serviceName ?? selectedPackage.name
  const publishedLabel = publishedPlan?.publishedAt
    ? new Date(publishedPlan.publishedAt).toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric' })
    : undefined
  const episodeEndLabel = state.episode?.endsAt
    ? new Date(state.episode.endsAt).toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric' })
    : '待确认'
  const header = <header className="service-detail-nav consultation-summary-header"><button className="back-button" onClick={() => navigate('/app/home')}>返回</button><h1>本次咨询总结</h1></header>

  useEffect(() => {
    if (documentation.mode !== 'server') return
    if (!appointment && appointmentId) {
      void consultation.refreshAppointments()
      return
    }
    if (!appointment) return
    if (state.appointment?.id !== appointment.id) dispatch({ type: 'activateAppointment', appointmentId: appointment.id })
    void documentation.load(appointment.id, 'user')
  }, [appointment?.id, appointmentId, documentation.load, documentation.mode])

  if (documentation.mode === 'server' && documentation.busy && !documentationRecord) return <div className="page-stack summary-page consultation-summary-page">{header}<section className="summary-pending-state" aria-live="polite"><span className="summary-state-icon"><Icon name="clock" /></span><h2>正在读取本次咨询总结</h2><p>请稍候，不需要重复操作。</p></section></div>
  if (documentation.mode === 'server' && documentation.error && !documentationRecord) return <div className="page-stack summary-page consultation-summary-page">{header}<Card className="summary-empty-state"><span className="summary-state-icon"><Icon name="note" /></span><h2>暂时无法读取总结</h2><p>{documentation.error}</p><Button onClick={() => appointment && void documentation.load(appointment.id, 'user')}>重新加载</Button></Card></div>
  if (!appointment || appointment.status !== 'completed') return <div className="page-stack summary-page consultation-summary-page">{header}<Card className="summary-empty-state"><span className="summary-state-icon"><Icon name="note" /></span><h2>还没有可查看的总结</h2><p>咨询结束后，经 IBCLC 确认的建议会显示在这里。</p><Button onClick={() => navigate('/app/home')}>返回妈妈主页</Button></Card></div>

  if (!publishedPlan) return <div className="page-stack summary-page consultation-summary-page">{header}<section className="summary-pending-state" aria-labelledby="summary-pending-title"><span className="summary-state-icon"><Icon name="clock" /></span><Badge tone="green">总结整理中</Badge><h2 id="summary-pending-title">{expertShortName} 正在整理本次建议</h2><p>完成后会通知你，并显示第一个行动、观察重点和后续安排。</p></section></div>

  return <div className="page-stack summary-page consultation-summary-page">{header}
    <section className="consultation-summary-intro" aria-labelledby="consultation-summary-title"><span className="consultation-summary-kicker">{expertShortName} 给你的总结</span><h2 id="consultation-summary-title">“{concernLabel}”</h2><p>{publishedPlan.summary}</p><div className="consultation-summary-author"><ExpertAvatar expertId={appointment?.ibclcId} expertName={expertName} className="consultation-summary-author-avatar" /><div><strong>{expertName}</strong><small>{publishedLabel ? `${publishedLabel} 已确认` : '已确认'}</small></div></div></section>
    {primaryTask && <Card className="consultation-summary-focus"><span className="summary-section-kicker">今天先做这一件事</span><h2>{primaryTask.title}</h2><p>{primaryTask.description}</p><Button size="md" onClick={() => navigate('/app/plan')}>查看怎么做 <Icon name="arrow" /></Button></Card>}
    {nextTasks.length > 0 && <section className="consultation-summary-section" aria-labelledby="consultation-next-title"><div className="consultation-summary-section-heading"><h2 id="consultation-next-title">接下来几天</h2><span>一次只做一小步</span></div><div className="consultation-summary-steps">{nextTasks.map((task, index) => <article key={task.id}><span className="consultation-step-number">{index + 2}</span><div><small>{task.dueLabel}</small><strong>{task.title}</strong><p>{task.description}</p></div></article>)}</div></section>}
    <section className="consultation-summary-section summary-observe" aria-labelledby="consultation-observe-title"><div className="consultation-summary-section-heading"><h2 id="consultation-observe-title">留意这些变化</h2><span>不用记得很完整</span></div><p>留意下一次喂养时的真实感受，看看是否更接近我们共同确认的目标。</p><ul>{publishedPlan.goals.map((goal) => <li key={goal}><Icon name="check" /><span>{goal}</span></li>)}</ul><button className="text-button summary-plan-link" onClick={() => navigate('/app/plan')}>查看完整行动计划 <Icon name="arrow" /></button></section>
    <section className="consultation-summary-help" aria-labelledby="consultation-help-title"><span><Icon name="shield" /></span><div><h2 id="consultation-help-title">需要更多帮助时</h2><p>如果执行后仍不舒服或有新的担心，先记录下变化，下次跟进时告诉 {expertShortName}。紧急情况请联系当地急救服务。</p></div></section>
    <details className="consultation-summary-meta"><summary><span><strong>咨询与服务信息</strong><small>{appointment ? `${formatAppointmentDay(appointment.start, appointment.timezone)} · ${expertShortName}` : expertShortName}</small></span><span className="details-chevron">⌄</span></summary><dl><div><dt>服务包</dt><dd>{serviceName}</dd></div><div><dt>本次咨询</dt><dd>{formatAppointmentRange(appointment.start, appointment.end, appointment.timezone)}</dd></div><div><dt>服务周期</dt><dd>至 {episodeEndLabel}</dd></div><div><dt>剩余咨询</dt><dd>{state.episode?.remainingSessions ?? 0} 次</dd></div></dl></details>
  </div>
}

function ServiceProgressPage() {
  const { state } = useProduct()
  const navigate = useNavigate()
  const { episodeId } = useParams()
  const episode = episodeId ? state.episodes.find((item) => item.id === episodeId) : state.episode
  const order = episode ? state.orders.find((item) => item.id === episode.orderId && item.status === 'paid') : undefined
  const packageItem = state.packages.find((item) => item.id === order?.packageId)

  if (!episode || !packageItem) {
    return <div className="page-stack service-progress-page"><header className="service-detail-nav"><button className="back-button" onClick={() => navigate('/app/home')}>返回</button><h1>服务进度</h1></header><EmptyState title="暂时找不到这个服务包" body="服务信息可能已更新，请从妈妈主页重新进入。" action={<Button onClick={() => navigate('/app/home')}>返回妈妈主页</Button>} /></div>
  }

  const totalSessions = Math.max(0, packageItem.sessions)
  const remainingSessions = Math.min(totalSessions, Math.max(0, episode.remainingSessions))
  const completedSessions = Math.max(0, totalSessions - remainingSessions)
  const episodeStatus = episode.status === 'active' ? { label: '服务进行中', tone: 'green' as const } : episode.status === 'completed' ? { label: '服务已完成', tone: 'blue' as const } : episode.status === 'paused' ? { label: '服务已暂停', tone: 'amber' as const } : episode.status === 'cancelled' ? { label: '服务已取消', tone: 'neutral' as const } : { label: '服务准备中', tone: 'neutral' as const }
  const appointments = state.appointments.filter((item) => item.episodeId === episode.id && item.status !== 'held').sort((a, b) => Date.parse(a.start) - Date.parse(b.start))
  const latestExpert = appointments.filter((item) => item.status !== 'cancelled').at(-1)
  const timeLabels = (date: string, timeZone?: string) => ({ dateLabel: new Date(date).toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric', timeZone }), timeLabel: new Date(date).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', timeZone }) })
  const events: MeServiceEvent[] = [{ id: `order-${order!.id}`, date: order!.createdAt, ...timeLabels(order!.createdAt), title: '服务包已购买', description: `${packageItem.durationDays} 天支持 · ${totalSessions} 次 IBCLC 在线咨询` }]
  events.push(...demoServiceHistory(state.user.id, episode.id, order!.createdAt, import.meta.env.VITE_CONSULTATION_DEV_AUTH === 'true'))
  for (const appointment of appointments) {
    const completed = appointment.status === 'completed'
    const cancelled = appointment.status === 'cancelled'
    events.push({ id: appointment.id, date: appointment.start, ...timeLabels(appointment.start, appointment.timezone), title: completed ? '咨询已结束' : cancelled ? '预约已取消' : appointment.status === 'in_progress' ? '咨询进行中' : '已预约咨询', author: appointment.ibclcName, description: `预约时间：${formatAppointmentDay(appointment.start, appointment.timezone)} · ${formatAppointmentRange(appointment.start, appointment.end, appointment.timezone)}`, action: cancelled ? undefined : { label: completed ? '查看咨询总结' : '查看预约', onClick: () => navigate(completed ? `/app/consultations/${appointment.id}/summary` : `/app/appointments/${appointment.id}`) } })
  }
  events.sort((a, b) => Date.parse(a.date) - Date.parse(b.date))

  return <div className="page-stack service-progress-page has-care-timeline">
    <header className="service-detail-nav"><button className="back-button" onClick={() => navigate('/app/home')}>返回</button><h1>服务进度</h1></header>
    <MeServiceTimeline statusLabel={episodeStatus.label} events={events} identity={<div className="care-service-identity">{latestExpert ? <ExpertAvatar expertId={latestExpert.ibclcId} expertName={latestExpert.ibclcName} className="care-expert-portrait" /> : <span className="care-team-icon"><Icon name="users" /></span>}<div className="care-service-copy"><h2>{packageItem.name}</h2><p>{latestExpert?.ibclcName ?? 'IBCLC 专家团队'}</p><small>{completedSessions} 次已使用 · 剩余 {remainingSessions}/{totalSessions} 次咨询</small></div><span className="care-service-duration">{packageItem.durationDays} 天支持</span></div>} />
  </div>
}

function RenewPage() {
  const { state, dispatch } = useProduct()
  const navigate = useNavigate()
  return <div className="page-stack renew-page"><PageIntro title="继续支持" back /><div className="package-list">{state.packages.map((pkg) => <Card key={pkg.id} className={`package-card ${pkg.id === state.selectedPackageId ? 'recommended' : ''}`}><div className="package-top"><div><h2>{pkg.name}</h2><p>{pkg.durationDays} 天 · {pkg.sessions} 次咨询</p></div><strong className="price">${pkg.price}</strong></div><Button size="sm" onClick={() => { dispatch({ type: 'selectPackage', packageId: pkg.id }); navigate('/app/checkout') }}>选择</Button></Card>)}</div></div>
}

function SelfManagementPage() {
  return <div className="page-stack self-page"><PageIntro title="自主管理" back /><Card className="soft-note"><h3>Care Plan 已保留</h3></Card><div className="self-list"><div><Icon name="plan" /><span>任务与提醒</span><Badge tone="green">保留</Badge></div><div><Icon name="note" /><span>周期总结</span><Badge tone="green">保留</Badge></div><div><Icon name="shield" /><span>数据授权</span><button className="text-button">管理</button></div></div><Button size="lg">保存下一步</Button><p className="legal-note">紧急情况请联系当地急救服务。</p></div>
}

function ReferralPage() {
  const [submitted, setSubmitted] = useState(false)
  return <div className="page-stack referral-page"><PageIntro title="转介与帮助" back /><Card className="referral-card"><div className="referral-icon"><Icon name="shield" /></div><h2>需要更多支持？</h2><p>你的 IBCLC 可以协助连接当地资源。</p><label className="check-row"><input type="checkbox" /><span>请联系我讨论转介</span></label><Button onClick={() => setSubmitted(true)} disabled={submitted}>{submitted ? '已记录' : '提交请求'}</Button></Card>{submitted && <div className="success-banner"><Icon name="check" /><div><strong>请求已记录</strong></div></div>}<p className="legal-note">紧急情况请联系当地急救服务。</p></div>
}

export default function UserApp() {
  const location = useLocation()
  const isAgentRoute = location.pathname.startsWith('/app/agent') || location.pathname.startsWith('/app/cozymate')
  return <UserShell>
    <div className="agent-route-keepalive" hidden={!isAgentRoute}><AgentPage isActive={isAgentRoute} /></div>
    {!isAgentRoute && <Routes>
      <Route path="home" element={<HomePage />} /><Route path="me" element={<MorePage />} /><Route path="baby" element={<BabyPage />} /><Route path="records" element={<RecordsPage />} /><Route path="privacy" element={<PrivacyPage />} /><Route path="settings" element={<PrivacyPage />} /><Route path="plan" element={<PlanPage />} /><Route path="more" element={<MorePage />} />
      <Route path="services" element={<ServicesPage />} /><Route path="services/:packageId" element={<ServiceDetailPage />} /><Route path="service-detail" element={<ServiceDetailPage />} /><Route path="services/:packageId/eligibility" element={<ServiceDetailPage initialPurchaseStep="eligibility" />} /><Route path="eligibility" element={<ServiceDetailPage initialPurchaseStep="eligibility" />} /><Route path="checkout" element={<ServiceDetailPage initialPurchaseStep="eligibility" />} /><Route path="checkout/:orderId" element={<ServiceDetailPage initialPurchaseStep="eligibility" />} /><Route path="intake" element={<IntakePage />} /><Route path="intake/:episodeId" element={<IntakePage />} /><Route path="appointment" element={<AppointmentPage />} /><Route path="appointments" element={<AppointmentPage />} /><Route path="appointments/:appointmentId" element={<AppointmentPage />} /><Route path="consult/:appointmentId/prep" element={<ConsultPrepPage />} /><Route path="consult/:appointmentId/room" element={<VideoPage />} /><Route path="video" element={<VideoPage />} /><Route path="summary" element={<SummaryPage />} /><Route path="consultations/:appointmentId/summary" element={<SummaryPage />} /><Route path="care-episodes/:episodeId/summary" element={<SummaryPage />} /><Route path="care-episodes/:episodeId/progress" element={<ServiceProgressPage />} /><Route path="care-episodes/:episodeId/care-plan" element={<PlanPage />} /><Route path="renew" element={<RenewPage />} /><Route path="care-episodes/:episodeId/renew" element={<RenewPage />} /><Route path="self-management" element={<SelfManagementPage />} /><Route path="care-episodes/:episodeId/self-management" element={<SelfManagementPage />} /><Route path="referral" element={<ReferralPage />} /><Route path="referrals/:referralId" element={<ReferralPage />} />
      <Route path="*" element={<HomePage />} />
    </Routes>}
  </UserShell>
}
