import { Fragment, useEffect, useId, useRef, useState, type ReactNode } from 'react'
import { Icon } from './UI'
import type { Appointment, EpisodeStatus } from '../types'
import { consultationCountdown } from '../features/consultation/appointments'

export interface MeServiceEvent {
  id: string
  date: string
  dateLabel: string
  timeLabel: string
  title: string
  description: string
  author?: string
  action?: { label: string; onClick: () => void }
}

export function MeServiceTimeline({ identity, events, statusLabel }: { identity: ReactNode; events: MeServiceEvent[]; statusLabel: string }) {
  const scroller = useRef<HTMLDivElement>(null)
  const [awayFromLatest, setAwayFromLatest] = useState(false)
  const scrollTo = (latest: boolean) => {
    const target = scroller.current
    target?.scrollTo({ top: latest ? target.scrollHeight : 0, behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth' })
  }
  useEffect(() => {
    const target = scroller.current
    if (target) target.scrollTop = target.scrollHeight
    setAwayFromLatest(false)
  }, [events.at(-1)?.id])
  return <section className="care-progress-view">
    {identity}
    {events.length > 1 && <button type="button" className="care-earlier" onClick={() => scrollTo(false)}>↑ 查看更早记录</button>}
    <div ref={scroller} className="care-history-scroll" tabIndex={0} role="region" aria-label="服务时间轴" onScroll={() => { const target = scroller.current; if (target) setAwayFromLatest(target.scrollHeight - target.clientHeight - target.scrollTop > 70) }}>
      <ol className="care-history">{events.map((event, index) => <li className={`care-event${index === events.length - 1 ? ' is-latest' : ''}`} key={event.id}>
        <div className="care-event-time"><time dateTime={event.date}>{event.dateLabel}<span>{event.timeLabel}</span></time></div><span className="care-event-dot" aria-hidden="true" />
        <article className="care-event-card"><div className="care-event-title"><h3>{event.title}</h3></div>{event.author && <span className="care-event-author">{event.author}</span>}<p>{event.description}</p>{event.action && <button type="button" className="care-artifact" onClick={event.action.onClick}>{event.action.label}<span className="care-artifact-arrow" aria-hidden="true">→</span></button>}</article>
      </li>)}</ol>
      <p className="care-timeline-end">已显示当前服务记录<span>{statusLabel} · 仅展示已同步的信息</span></p>
    </div>
    {awayFromLatest && <button type="button" className="care-jump-latest" onClick={() => scrollTo(true)}>↓ 回到最近记录</button>}
  </section>
}

export function MeSectionIcon({ support = false }: { support?: boolean }) {
  return support
    ? <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M12 12S5 8.5 5 5.5C5 2 9 1.5 12 5c3-3.5 7-3 7 .5 0 3-7 6.5-7 6.5ZM12 22v-5m0 5c-6 0-9-4-9-9 3 0 4 2 5 5m4 4c6 0 9-4 9-9-3 0-4 2-5 5" /></svg>
    : <svg viewBox="0 0 28 28" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M14 22S3 16 3 9.5C3 4 10 3 14 8c4-5 11-4 11 1.5 0 3-2.5 6-5 8" /><path d="M11 26c0-8 4-12 12-12-1 7-5 10-11 9m1-1 6-5" /></svg>
}

export function MeMilkTrend({ records }: { records: { date: string; amount: number | undefined }[] }) {
  const [days, setDays] = useState(7)
  const glowId = useId()
  const dateKey = (date: Date) => `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`
  const totals = new Map<string, number>()
  for (const record of records) {
    const date = new Date(record.date)
    if (record.amount === undefined || !Number.isFinite(record.amount) || record.amount < 0 || !Number.isFinite(date.getTime())) continue
    const key = dateKey(date)
    totals.set(key, (totals.get(key) ?? 0) + record.amount)
  }
  const today = new Date()
  const todayKey = dateKey(today)
  const points = Array.from({ length: days }, (_, index) => {
    const date = new Date(today)
    date.setDate(today.getDate() - days + 1 + index)
    return { date, key: dateKey(date), value: totals.get(dateKey(date)) }
  })
  const measured = points.filter((point) => point.value !== undefined)
  const maximum = Math.max(50, ...measured.map((point) => point.value!)) * 1.3
  const x = (index: number) => 20 + index * 280 / (days - 1)
  const y = (value: number) => 150 - value / maximum * 108
  const total = totals.get(todayKey)
  return <section className="milk-trend" aria-label="奶量趋势">
    <div className="milk-trend-heading"><h4><Icon name="drop" />奶量趋势</h4><div className="milk-range" role="group" aria-label="趋势时间范围">{[7, 30].map((range) => <button key={range} type="button" aria-pressed={days === range} onClick={() => setDays(range)}>{range}天</button>)}</div></div>
    <div className="milk-total"><strong>{total ?? '—'}</strong><span>ml</span></div><p className="milk-total-label">今日泵奶量</p>
    <svg className="milk-line-chart" viewBox="0 0 320 192" role="img" aria-label={`${days}天泵奶量趋势，今日${total === undefined ? '未记录' : `${total}毫升`}`}>
      <defs><radialGradient id={glowId}><stop stopColor="#f2c49d" stopOpacity=".5" /><stop offset="1" stopColor="#f2c49d" stopOpacity="0" /></radialGradient></defs>
      <path d="M20 150H300" stroke="#967c69" strokeOpacity=".45" strokeDasharray="3 4" />
      {points.map((point, index) => {
        const previous = points[index - 1]
        const px = x(index)
        const py = point.value === undefined ? 150 : y(point.value)
        const middle = (x(index - 1) + px) / 2
        return <Fragment key={point.key}>
          {point.value !== undefined && <>
            {previous?.value !== undefined && <path d={`M${x(index - 1)} ${y(previous.value)} C${middle} ${y(previous.value)},${middle} ${py},${px} ${py}`} fill="none" stroke="#fff9f4" strokeWidth="1.8" />}
            {point.key === todayKey && <><circle cx={px} cy={py} r="30" fill={`url(#${glowId})`} /><path d={`M${px} ${py + 10}V150`} stroke="#d9b394" strokeDasharray="3 4" /><circle cx={px} cy={py} r="7" fill="none" stroke="#e9bb91" strokeWidth="2" /><text x={px} y={py - 17} textAnchor="end" fill="#f0c6a3" fontSize="11">今日 {point.value} ml</text></>}
            <circle cx={px} cy={py} r={point.key === todayKey ? 3.8 : 2.8} fill="#fff9f4"><title>{point.date.getMonth() + 1}/{point.date.getDate()} · {point.value} ml</title></circle>
          </>}
          {(days === 7 || index === 0 || index === days - 1 || index % 7 === 0) && <text x={px} y="177" textAnchor="middle" fill={point.key === todayKey ? '#edc5a6' : '#cbbeb5'} fontSize="10">{point.key === todayKey ? '今日' : `${point.date.getMonth() + 1}/${point.date.getDate()}`}</text>}
        </Fragment>
      })}
    </svg>
    <p className="milk-chart-note">{!measured.length ? '暂无泵奶量记录，添加后即可查看趋势' : measured.length === 1 ? '目前仅有一天数据，连续记录后可查看曲线' : '仅展示已记录的泵奶量，未记录日期留空'}</p>
  </section>
}

export function MeStatusCard({ kind, label, value, detail, onClick }: {
  kind: 'rest' | 'comfort' | 'mood' | 'lactation'
  label: string
  value: string
  detail?: string
  onClick: () => void
}) {
  const measured = value.match(/^(.*?)\s*(小时|ml|分钟|次)$/i)
  return <button type="button" className={`my-status-card ${kind}${measured ? ' measured' : ''}`} onClick={onClick} aria-label={`${label}，${value}${detail ? `，${detail}` : ''}`}>
    <span className="my-status-card-label">{label}</span>
    <span className="my-status-chevron" aria-hidden="true"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="m6 3 5 5-5 5" /></svg></span>
    <span className="my-status-decoration" aria-hidden="true" />
    <span className="my-status-card-bottom"><strong className="my-status-value">{measured ? <>{measured[1]}<span className="my-status-unit">{measured[2]}</span></> : value}</strong>{detail && <small className="my-status-detail">{detail}</small>}</span>
  </button>
}

export function MeExpertServiceCard({ name, status, durationDays, remainingSessions, identity, appointment, appointmentLabel, appointmentTime, nextStep, actionLabel, actionDisabled, onAction, onProgress }: {
  name: string
  status: EpisodeStatus
  durationDays: number
  remainingSessions: number
  identity: ReactNode
  appointment?: Appointment
  appointmentLabel?: string
  appointmentTime?: string
  nextStep: string
  actionLabel: string
  actionDisabled?: boolean
  onAction: () => void
  onProgress: () => void
}) {
  const [now, setNow] = useState(Date.now)
  useEffect(() => {
    if (!appointment) return
    const timer = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(timer)
  }, [appointment?.id])
  const statusText: Record<EpisodeStatus, string> = {
    active: '服务进行中', provisioning_pending: '已购服务', paused: '服务已暂停', completed: '服务已完成', cancelled: '服务已取消',
  }
  const appointmentState = appointment?.status === 'in_progress' ? '咨询中'
    : appointment ? consultationCountdown(appointment, now) : ''
  return <section className="home-service-card has-expert-view" aria-label={`${name}，${statusText[status]}`}>
    <div className="expert-service-view">
      <div className="expert-service-status"><span aria-hidden="true" /><span>{statusText[status]}</span></div>
      <h3 className="expert-package-title">{name}</h3>
      {identity}
      <div className="expert-benefits"><span><i aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M7 3v4m10-4v4M4 10h16M5 5h14a1 1 0 0 1 1 1v14H4V6a1 1 0 0 1 1-1ZM8 14h1m6 0h1m-8 3h1m6 0h1" /></svg></i><span>{durationDays} 天支持</span></span><span><i aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d="M20 11a8 8 0 0 1-8 8H5l-3 3V11a9 9 0 0 1 18 0ZM7 9h8m-8 4h5" /></svg></i><span>剩余 {remainingSessions} 次咨询</span></span></div>
      <div className="expert-service-detail"><span className="expert-detail-label">{appointment ? appointmentLabel : '下一步'}</span>{appointmentState && <span className="expert-appointment-state">{appointmentState}</span>}<p className="expert-detail-copy">{appointment ? appointmentTime : nextStep}</p></div>
      <div className="expert-service-footer"><button type="button" className="expert-progress" aria-label={`查看${name}服务进度`} onClick={onProgress}>服务进度 <Icon name="chevron-right" /></button><button type="button" className={`expert-primary${appointment ? ' outline' : ''}`} disabled={actionDisabled} onClick={onAction}>{actionLabel}</button></div>
    </div>
  </section>
}
