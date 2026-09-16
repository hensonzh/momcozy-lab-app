import type { Appointment } from '../../types.ts'

/** UI hint only. Server admission still requires its explicit non-production demo switch. */
export function isConsultationDemo(mode: 'browser_mock' | 'server', devAuth: unknown): boolean {
  return mode === 'browser_mock' || devAuth === 'true'
}

export function canEnterConsultationByTime(
  appointment: Pick<Appointment, 'start' | 'end' | 'status'>,
  now = Date.now(),
  demoMode = false,
): boolean {
  if (appointment.status !== 'confirmed' && appointment.status !== 'in_progress') return false
  if (demoMode || appointment.status === 'in_progress') return true
  return now >= Date.parse(appointment.start) - 10 * 60 * 1000
    && now <= Date.parse(appointment.end) + 15 * 60 * 1000
}

/** Shared presentation only; admission remains controlled by the consultation gateway. */
export function consultationCountdown(appointment: Pick<Appointment, 'start' | 'end'>, now = Date.now()): string {
  const start = new Date(appointment.start).getTime()
  const end = new Date(appointment.end).getTime()
  if (!Number.isFinite(start) || !Number.isFinite(end)) return '已预约'
  if (now >= end) return '时间已过'
  if (now >= start) return '可以进入'
  const total = Math.max(0, Math.floor((start - now) / 1000))
  const days = Math.floor(total / 86400)
  const hours = String(Math.floor((total % 86400) / 3600)).padStart(2, '0')
  const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, '0')
  const seconds = String(total % 60).padStart(2, '0')
  return days ? `${days}天 ${hours}:${minutes}` : `${hours}:${minutes}:${seconds}`
}

const actionableStatusPriority: Partial<Record<Appointment['status'], number>> = {
  in_progress: 0,
  confirmed: 1,
  held: 2,
}

/** Prefer the consultation that needs action; otherwise show the latest history item. */
export function preferredAppointmentForEpisode(appointments: Appointment[], episodeId: string): Appointment | undefined {
  return appointments
    .filter((appointment) => appointment.episodeId === episodeId)
    .sort((left, right) => {
      const leftPriority = actionableStatusPriority[left.status] ?? 3
      const rightPriority = actionableStatusPriority[right.status] ?? 3
      if (leftPriority !== rightPriority) return leftPriority - rightPriority
      return new Date(right.start).getTime() - new Date(left.start).getTime()
    })[0]
}
