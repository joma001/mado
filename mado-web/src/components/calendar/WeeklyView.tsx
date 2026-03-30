'use client'

import { useMemo } from 'react'
import {
  startOfWeek, addDays, format, isSameDay, isToday,
  differenceInMinutes, parseISO,
} from 'date-fns'
import { useCalendarStore } from '@/stores/calendarStore'
import { useSettingsStore } from '@/stores/settingsStore'
import { GOOGLE_COLOR_MAP, type CalendarEvent } from '@/types/calendar'
import { EventBlock } from './EventBlock'

const HOURS = Array.from({ length: 24 }, (_, i) => i)
const DEFAULT_HOUR_HEIGHT = 48

export function WeeklyView() {
  const { events, calendars, selectedDate } = useCalendarStore()
  const { settings } = useSettingsStore()

  const hourHeight = DEFAULT_HOUR_HEIGHT
  const weekStart = startOfWeek(selectedDate, { weekStartsOn: (settings.startOfWeek - 1) as 0 | 1 | 2 | 3 | 4 | 5 | 6 })
  const days = useMemo(() => {
    const all = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i))
    if (!settings.showWeekends) return all.filter((d) => d.getDay() !== 0 && d.getDay() !== 6)
    return all
  }, [weekStart, settings.showWeekends])

  const calColorMap = useMemo(() => {
    const map: Record<string, string> = {}
    for (const c of calendars) map[c.id] = c.backgroundColor
    return map
  }, [calendars])

  function eventColor(event: CalendarEvent): string {
    if (event.colorId && GOOGLE_COLOR_MAP[event.colorId]) return GOOGLE_COLOR_MAP[event.colorId]
    return calColorMap[event.calendarId] ?? '#5B7FFF'
  }

  function eventsForDay(day: Date): CalendarEvent[] {
    return events.filter((e) => {
      if (e.isAllDay) return false
      const start = parseISO(e.startDate)
      return isSameDay(start, day)
    })
  }

  function allDayEventsForDay(day: Date): CalendarEvent[] {
    return events.filter((e) => {
      if (!e.isAllDay) return false
      const start = parseISO(e.startDate)
      return isSameDay(start, day)
    })
  }

  // Column layout for overlapping events
  function layoutEvents(dayEvents: CalendarEvent[]): { event: CalendarEvent; column: number; totalColumns: number }[] {
    const sorted = [...dayEvents].sort((a, b) => parseISO(a.startDate).getTime() - parseISO(b.startDate).getTime())
    const result: { event: CalendarEvent; column: number; totalColumns: number }[] = []
    const columns: CalendarEvent[][] = []

    for (const event of sorted) {
      const start = parseISO(event.startDate)
      let placed = false
      for (let c = 0; c < columns.length; c++) {
        const last = columns[c][columns[c].length - 1]
        if (parseISO(last.endDate).getTime() <= start.getTime()) {
          columns[c].push(event)
          result.push({ event, column: c, totalColumns: 0 })
          placed = true
          break
        }
      }
      if (!placed) {
        columns.push([event])
        result.push({ event, column: columns.length - 1, totalColumns: 0 })
      }
    }

    // Set totalColumns for each group
    for (const item of result) item.totalColumns = columns.length || 1
    return result
  }

  // Current time indicator
  const now = new Date()
  const currentMinutes = now.getHours() * 60 + now.getMinutes()
  const currentTop = (currentMinutes / 60) * hourHeight

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      {/* All-day row */}
      <div className="flex border-b border-divider">
        <div className="w-14 shrink-0" />
        {days.map((day) => {
          const allDay = allDayEventsForDay(day)
          return (
            <div key={day.toISOString()} className="flex-1 border-l border-divider px-1 py-1">
              {allDay.map((e) => (
                <div
                  key={e.id}
                  className="mb-0.5 truncate rounded px-1.5 py-0.5 text-[10px] font-medium text-on-accent"
                  style={{ backgroundColor: eventColor(e) }}
                >
                  {e.title}
                </div>
              ))}
            </div>
          )
        })}
      </div>

      {/* Day headers */}
      <div className="flex border-b border-divider">
        <div className="w-14 shrink-0" />
        {days.map((day) => (
          <div key={day.toISOString()} className="flex-1 border-l border-divider py-2 text-center">
            <p className="text-[10px] font-medium text-text-tertiary">{format(day, 'EEE')}</p>
            <p
              className={`mt-0.5 inline-flex h-7 w-7 items-center justify-center rounded-full text-sm font-semibold ${
                isToday(day)
                  ? 'bg-accent text-on-accent'
                  : 'text-text-primary'
              }`}
            >
              {format(day, 'd')}
            </p>
          </div>
        ))}
      </div>

      {/* Time grid */}
      <div className="flex-1 overflow-y-auto">
        <div className="relative flex" style={{ height: hourHeight * 24 }}>
          {/* Hour labels */}
          <div className="w-14 shrink-0">
            {HOURS.map((h) => (
              <div
                key={h}
                className="absolute right-2 text-[10px] text-text-tertiary"
                style={{ top: h * hourHeight - 6 }}
              >
                {settings.use24HourTime
                  ? `${String(h).padStart(2, '0')}:00`
                  : h === 0 ? '12 AM' : h < 12 ? `${h} AM` : h === 12 ? '12 PM' : `${h - 12} PM`}
              </div>
            ))}
          </div>

          {/* Day columns */}
          {days.map((day) => {
            const dayEvents = eventsForDay(day)
            const laid = layoutEvents(dayEvents)
            const showTimeLine = isToday(day)

            return (
              <div key={day.toISOString()} className="relative flex-1 border-l border-divider">
                {/* Hour lines */}
                {HOURS.map((h) => (
                  <div
                    key={h}
                    className="absolute inset-x-0 border-t border-divider"
                    style={{ top: h * hourHeight }}
                  />
                ))}

                {/* Current time indicator */}
                {showTimeLine && (
                  <div className="absolute inset-x-0 z-20" style={{ top: currentTop }}>
                    <div className="h-0.5 bg-red-500" />
                    <div className="absolute -left-1 -top-1 h-2.5 w-2.5 rounded-full bg-red-500" />
                  </div>
                )}

                {/* Events */}
                {laid.map(({ event, column, totalColumns }) => {
                  const start = parseISO(event.startDate)
                  const end = parseISO(event.endDate)
                  const startMinutes = start.getHours() * 60 + start.getMinutes()
                  const duration = Math.max(differenceInMinutes(end, start), 15)
                  const top = (startMinutes / 60) * hourHeight
                  const height = (duration / 60) * hourHeight
                  const width = `${100 / totalColumns}%`
                  const left = `${(column / totalColumns) * 100}%`

                  return (
                    <EventBlock
                      key={event.id}
                      event={event}
                      color={eventColor(event)}
                      style={{ top, height: Math.max(height, 20), width, left, position: 'absolute' }}
                    />
                  )
                })}
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
