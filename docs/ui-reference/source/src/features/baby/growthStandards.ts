import type { BabyGrowthMetric, BabySex } from '../../types'

export const WHO_GROWTH_MAX_MONTHS = 6

export type WhoGrowthReferencePoint = {
  ageDays: number
  lower: number
  upper: number
  source: 'weekly' | 'monthly'
}

type WhoGrowthSeries = {
  lower: readonly number[]
  upper: readonly number[]
}

type WhoGrowthMetricReference = {
  weekly: Record<Exclude<BabySex, 'unspecified'>, WhoGrowthSeries>
  monthly: Record<Exclude<BabySex, 'unspecified'>, WhoGrowthSeries>
}

/* WHO Child Growth Standards, -2 SD to +2 SD. Weeks 0–13 come from the
   official birth-to-13-weeks z-score tables; months 0–6 come from the
   corresponding monthly tables. Verified against the WHO workbooks on
   2026-09-06.

   https://www.who.int/tools/child-growth-standards/standards/weight-for-age
   https://www.who.int/tools/child-growth-standards/standards/length-height-for-age
   https://www.who.int/tools/child-growth-standards/standards/head-circumference-for-age
*/
const whoGrowthReference: Record<BabyGrowthMetric, WhoGrowthMetricReference> = {
  weight: {
    weekly: {
      female: {
        lower: [2.4, 2.5, 2.7, 2.9, 3.1, 3.3, 3.5, 3.7, 3.8, 4, 4.1, 4.3, 4.4, 4.5],
        upper: [4.2, 4.4, 4.7, 5, 5.4, 5.7, 6, 6.2, 6.5, 6.7, 6.9, 7.1, 7.3, 7.5],
      },
      male: {
        lower: [2.5, 2.6, 2.8, 3.1, 3.3, 3.5, 3.8, 4, 4.2, 4.4, 4.5, 4.7, 4.9, 5],
        upper: [4.4, 4.6, 4.9, 5.3, 5.7, 6, 6.3, 6.6, 6.9, 7.2, 7.4, 7.6, 7.8, 8],
      },
    },
    monthly: {
      female: { lower: [2.4, 3.2, 3.9, 4.5, 5, 5.4, 5.7], upper: [4.2, 5.5, 6.6, 7.5, 8.2, 8.8, 9.3] },
      male: { lower: [2.5, 3.4, 4.3, 5, 5.6, 6, 6.4], upper: [4.4, 5.8, 7.1, 8, 8.7, 9.3, 9.8] },
    },
  },
  length: {
    weekly: {
      female: {
        lower: [45.4, 46.6, 47.7, 48.6, 49.5, 50.3, 51.1, 51.8, 52.5, 53.2, 53.8, 54.4, 55, 55.6],
        upper: [52.9, 54.1, 55.3, 56.3, 57.3, 58.2, 59, 59.9, 60.6, 61.4, 62.1, 62.7, 63.4, 64],
      },
      male: {
        lower: [46.1, 47.3, 48.5, 49.5, 50.5, 51.4, 52.3, 53.1, 53.9, 54.6, 55.4, 56, 56.7, 57.3],
        upper: [53.7, 54.9, 56.2, 57.2, 58.3, 59.2, 60.2, 61, 61.9, 62.7, 63.4, 64.1, 64.8, 65.5],
      },
    },
    monthly: {
      female: { lower: [45.4, 49.8, 53, 55.6, 57.8, 59.6, 61.2], upper: [52.9, 57.6, 61.1, 64, 66.4, 68.5, 70.3] },
      male: { lower: [46.1, 50.8, 54.4, 57.3, 59.7, 61.7, 63.3], upper: [53.7, 58.6, 62.4, 65.5, 68, 70.1, 71.9] },
    },
  },
  'head-circumference': {
    weekly: {
      female: {
        lower: [31.5, 32.2, 32.9, 33.5, 34, 34.5, 34.9, 35.3, 35.6, 35.9, 36.2, 36.5, 36.8, 37],
        upper: [36.2, 36.9, 37.5, 38.2, 38.7, 39.2, 39.6, 40.1, 40.4, 40.8, 41.1, 41.4, 41.7, 42],
      },
      male: {
        lower: [31.9, 32.7, 33.5, 34.2, 34.8, 35.3, 35.7, 36.1, 36.5, 36.9, 37.2, 37.5, 37.9, 38.1],
        upper: [37, 37.6, 38.2, 38.9, 39.4, 39.9, 40.4, 40.8, 41.2, 41.6, 41.9, 42.3, 42.6, 42.9],
      },
    },
    monthly: {
      female: { lower: [31.5, 34.2, 35.8, 37.1, 38.1, 38.9, 39.6], upper: [36.2, 38.9, 40.7, 42, 43.1, 44, 44.8] },
      male: { lower: [31.9, 34.9, 36.8, 38.1, 39.2, 40.1, 40.9], upper: [37, 39.6, 41.5, 42.9, 44, 45, 45.8] },
    },
  },
}

function parseDateOnly(value: string): Date | undefined {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (!match) return undefined
  const year = Number(match[1])
  const month = Number(match[2]) - 1
  const day = Number(match[3])
  const date = new Date(Date.UTC(year, month, day))
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month || date.getUTCDate() !== day) return undefined
  return date
}

function dateOnlyFromDate(value: Date): Date | undefined {
  if (!Number.isFinite(value.getTime())) return undefined
  return new Date(Date.UTC(value.getFullYear(), value.getMonth(), value.getDate()))
}

function addUtcCalendarMonths(value: Date, months: number): Date {
  const year = value.getUTCFullYear()
  const month = value.getUTCMonth() + months
  const targetYear = year + Math.floor(month / 12)
  const targetMonth = ((month % 12) + 12) % 12
  const lastDay = new Date(Date.UTC(targetYear, targetMonth + 1, 0)).getUTCDate()
  return new Date(Date.UTC(targetYear, targetMonth, Math.min(value.getUTCDate(), lastDay)))
}

function differenceInCalendarDays(start: Date, end: Date): number {
  return Math.round((end.getTime() - start.getTime()) / 86_400_000)
}

export function babyAgeInDays(birthDate: string, at: Date = new Date()): number | undefined {
  const birth = parseDateOnly(birthDate)
  const end = dateOnlyFromDate(at)
  if (!birth || !end) return undefined
  const days = differenceInCalendarDays(birth, end)
  return days >= 0 ? days : undefined
}

export function babyAgeLabel(birthDate: string, at: Date = new Date()): string {
  const birth = parseDateOnly(birthDate)
  const end = dateOnlyFromDate(at)
  if (!birth || !end) return '月龄待完善'
  const days = differenceInCalendarDays(birth, end)
  if (days < 0) return '尚未出生'
  if (days === 0) return '出生当天'

  let months = (end.getUTCFullYear() - birth.getUTCFullYear()) * 12 + end.getUTCMonth() - birth.getUTCMonth()
  if (addUtcCalendarMonths(birth, months).getTime() > end.getTime()) months -= 1
  if (months >= 3 && months < 24) return `${months} 个月`
  if (months >= 24) {
    const years = Math.floor(months / 12)
    const remainingMonths = months % 12
    return `${years} 岁${remainingMonths ? ` ${remainingMonths} 个月` : ''}`
  }

  if (days < 14) return `${days} 天`
  const weeks = Math.floor(days / 7)
  const remainingDays = days % 7
  return `${weeks} 周${remainingDays ? ` ${remainingDays} 天` : ''}`
}

export function calendarMonthAgeInDays(birthDate: string, months: number): number | undefined {
  const birth = parseDateOnly(birthDate)
  if (!birth || months < 0 || !Number.isInteger(months)) return undefined
  return differenceInCalendarDays(birth, addUtcCalendarMonths(birth, months))
}

export function growthRecordAgeInDays(birthDate: string, measuredAt: string): number | undefined {
  const measured = new Date(measuredAt)
  return babyAgeInDays(birthDate, measured)
}

export function whoGrowthReferencePoints(
  metric: BabyGrowthMetric,
  sex: BabySex,
  birthDate: string,
): WhoGrowthReferencePoint[] {
  if (sex === 'unspecified') return []
  const metricReference = whoGrowthReference[metric]
  const weekly = metricReference.weekly[sex]
  const points: WhoGrowthReferencePoint[] = weekly.lower.map((lower, week) => ({
    ageDays: week * 7,
    lower,
    upper: weekly.upper[week],
    source: 'weekly',
  }))

  for (let month = 4; month <= WHO_GROWTH_MAX_MONTHS; month += 1) {
    const ageDays = calendarMonthAgeInDays(birthDate, month)
    if (ageDays === undefined) continue
    points.push({
      ageDays,
      lower: metricReference.monthly[sex].lower[month],
      upper: metricReference.monthly[sex].upper[month],
      source: 'monthly',
    })
  }

  return points.sort((a, b) => a.ageDays - b.ageDays)
}
