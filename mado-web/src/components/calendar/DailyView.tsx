'use client'

import { useMemo } from 'react'
import { isSameDay, isToday, parseISO, differenceInMinutes } from 'date-fns'
import { useCalendarStore } from '@/stores/calendarStore'
import { useSettingsStore } from '@/stores/settingsStore'
import { GOOGLE_COLOR_MAP, type CalendarEvent } from '@/types/calendar'
import { EventBlock } from './EventBlock'

const HOURS = Array.from({ length: 24 }, (_, i) => i)
const HOUR_HEIGHT = 48

export function DailyView() {
  const { events, calendars, selectedDate } = useCalendarStore()
  const { settings } = useSettingsStore()

  const calColorMap = useMemo(() => {
    const map: Record<string, string> = {}
    for (const c of calendars) map[c.id] = c.backgroundColor
    return map
  }, [calendars])

  function eventColor(event: CalendarEvent): string {
    if (event.colorId && GOOGLE_COLOR_MAP[event.colorId]) return GOOGLE_COLOR_MAP[event.colorId]
    return calColorMap[event.calendarId] ?? '#5B7FFF'
  }

  const dayEvents = events.filter((e) => {
    if (e.isAllDay) return false
    return isSameDay(parseISO(e.startDate), selectedDate)
  })

  const allDayEvents = events.filter((e) => {
    if (!e.isAllDay) return false
    return isSameDay(parseISO(e.startDate), selectedDate)
  })

  const now = new Date()
  const showTimeLine = isToday(selectedDate)
  const currentTop = ((now.getHours() * 60 + now.getMinutes()) / 60) * HOUR_HEIGHT

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      {/* All day */}
      {allDayEvents.length > 0 && (
        <div className="border-b border-divider px-16 py-1">
          {allDayEvents.map((e) => (
            <div
              key={e.id}
              className="mb-0.5 truncate rounded px-2 py-1 text-xs font-medium text-on-accent"
              style={{ backgroundColor: eventColor(e) }}
            >
              {e.title}
            </div>
          ))}
        </div>
      )}

      {/* Time grid */}
      <div className="flex-1 overflow-y-auto">
        <div className="relative flex" style={{ height: HOUR_HEIGHT * 24 }}>
          {/* Hour labels */}
          <div className="w-14 shrink-0">
            {HOURS.map((h) => (
              <div
                key={h}
                className="absolute right-2 text-[10px] text-text-tertiary"
                style={{ top: h * HOUR_HEIGHT - 6 }}
              >
                {settings.use24HourTime
                  ? `${String(h).padStart(2, '0')}:00`
                  : h === 0 ? '12 AM' : h < 12 ? `${h} AM` : h === 12 ? '12 PM' : `${h - 12} PM`}
              </div>
            ))}
          </div>

          {/* Single column */}
          <div className="relative flex-1 border-l border-divider">
            {HOURS.map((h) => (
              <div
                key={h}
                className="absolute inset-x-0 border-t border-divider"
                style={{ top: h * HOUR_HEIGHT }}
              />
            ))}

            {showTimeLine && (
              <div className="absolute inset-x-0 z-20" style={{ top: currentTop }}>
                <div className="h-0.5 bg-red-500" />
                <div className="absolute -left-1 -top-1 h-2.5 w-2.5 rounded-full bg-red-500" />
              </div>
            )}

            {dayEvents.map((event) => {
              const start = parseISO(event.startDate)
              const end = parseISO(event.endDate)
              const startMinutes = start.getHours() * 60 + start.getMinutes()
              const duration = Math.max(differenceInMinutes(end, start), 15)
              const top = (startMinutes / 60) * HOUR_HEIGHT
              const height = (duration / 60) * HOUR_HEIGHT

              return (
                <EventBlock
                  key={event.id}
                  event={event}
                  color={eventColor(event)}
                  style={{ top, height: Math.max(height, 20), left: '4px', right: '4px', position: 'absolute' }}
                />
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
