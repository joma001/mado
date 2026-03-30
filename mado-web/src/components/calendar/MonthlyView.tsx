'use client'

import { useMemo } from 'react'
import {
  startOfMonth, endOfMonth, startOfWeek, addDays, isSameMonth,
  isSameDay, isToday, parseISO, format,
} from 'date-fns'
import { useCalendarStore } from '@/stores/calendarStore'
import { GOOGLE_COLOR_MAP } from '@/types/calendar'

export function MonthlyView() {
  const { events, calendars, selectedDate, setSelectedDate, setViewMode } = useCalendarStore()

  const calColorMap = useMemo(() => {
    const map: Record<string, string> = {}
    for (const c of calendars) map[c.id] = c.backgroundColor
    return map
  }, [calendars])

  const weeks = useMemo(() => {
    const monthStart = startOfMonth(selectedDate)
    const gridStart = startOfWeek(monthStart)
    const rows: Date[][] = []
    let current = gridStart
    while (rows.length < 6) {
      const week: Date[] = []
      for (let i = 0; i < 7; i++) {
        week.push(current)
        current = addDays(current, 1)
      }
      rows.push(week)
      if (current > endOfMonth(selectedDate) && rows.length >= 4) break
    }
    return rows
  }, [selectedDate])

  const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      {/* Day headers */}
      <div className="flex border-b border-divider bg-surface-secondary">
        {dayLabels.map((d) => (
          <div key={d} className="flex-1 py-2 text-center text-[10px] font-medium text-text-tertiary">
            {d}
          </div>
        ))}
      </div>

      {/* Grid */}
      <div className="flex flex-1 flex-col">
        {weeks.map((week, wi) => (
          <div key={wi} className="flex flex-1 border-b border-divider">
            {week.map((day) => {
              const inMonth = isSameMonth(day, selectedDate)
              const today = isToday(day)
              const dayEvents = events.filter((e) => {
                const start = parseISO(e.startDate)
                return isSameDay(start, day)
              })

              return (
                <div
                  key={day.toISOString()}
                  onClick={() => { setSelectedDate(day); setViewMode('daily') }}
                  className={`flex flex-1 cursor-pointer flex-col border-r border-divider p-1 transition hover:bg-hover-bg ${
                    !inMonth ? 'bg-surface-secondary/50' : ''
                  }`}
                >
                  <span
                    className={`mb-1 inline-flex h-6 w-6 items-center justify-center self-start rounded-full text-xs font-medium ${
                      today
                        ? 'bg-accent text-on-accent'
                        : inMonth
                          ? 'text-text-primary'
                          : 'text-text-tertiary'
                    }`}
                  >
                    {format(day, 'd')}
                  </span>
                  <div className="space-y-px overflow-hidden">
                    {dayEvents.slice(0, 3).map((e) => {
                      const color = (e.colorId && GOOGLE_COLOR_MAP[e.colorId]) || calColorMap[e.calendarId] || '#5B7FFF'
                      return (
                        <div
                          key={e.id}
                          className="truncate rounded px-1 py-px text-[9px] font-medium text-on-accent"
                          style={{ backgroundColor: color }}
                        >
                          {e.title}
                        </div>
                      )
                    })}
                    {dayEvents.length > 3 && (
                      <p className="px-1 text-[9px] text-text-tertiary">+{dayEvents.length - 3} more</p>
                    )}
                  </div>
                </div>
              )
            })}
          </div>
        ))}
      </div>
    </div>
  )
}
