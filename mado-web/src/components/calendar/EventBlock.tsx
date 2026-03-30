'use client'

import { parseISO, format } from 'date-fns'
import type { CalendarEvent } from '@/types/calendar'
import type { CSSProperties } from 'react'

interface EventBlockProps {
  event: CalendarEvent
  color: string
  style?: CSSProperties
  onClick?: () => void
}

export function EventBlock({ event, color, style, onClick }: EventBlockProps) {
  const start = parseISO(event.startDate)
  const end = parseISO(event.endDate)
  const isPast = end < new Date()
  const timeStr = `${format(start, 'h:mm a')} – ${format(end, 'h:mm a')}`

  return (
    <div
      onClick={onClick}
      className="z-10 cursor-pointer overflow-hidden rounded-md px-1.5 py-0.5 text-on-accent transition hover:brightness-95"
      style={{
        ...style,
        backgroundColor: color,
        opacity: isPast ? 0.5 : event.isDeclined ? 0.6 : 1,
      }}
    >
      <p className="truncate text-[11px] font-medium leading-tight">{event.title}</p>
      <p className="truncate text-[9px] opacity-80">{timeStr}</p>
    </div>
  )
}
