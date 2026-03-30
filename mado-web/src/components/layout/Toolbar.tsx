'use client'

import { ChevronLeft, ChevronRight } from 'lucide-react'
import { format } from 'date-fns'
import { useCalendarStore } from '@/stores/calendarStore'
import type { CalendarViewMode } from '@/types/calendar'

const VIEW_MODES: { mode: CalendarViewMode; label: string }[] = [
  { mode: 'monthly', label: 'M' },
  { mode: 'weekly', label: 'W' },
  { mode: 'daily', label: 'D' },
]

export function Toolbar() {
  const { selectedDate, viewMode, navigateBack, navigateForward, goToToday, setViewMode } =
    useCalendarStore()

  const title = (() => {
    if (viewMode === 'monthly') return format(selectedDate, 'MMMM yyyy')
    if (viewMode === 'daily') return format(selectedDate, 'EEEE, MMMM d, yyyy')
    return format(selectedDate, 'MMMM yyyy')
  })()

  return (
    <div className="flex items-center gap-3 border-b border-divider bg-surface px-4 py-2.5">
      {/* Navigation */}
      <div className="flex items-center rounded-md bg-surface-secondary">
        <button onClick={navigateBack} className="p-1.5 text-text-secondary hover:text-text-primary">
          <ChevronLeft className="h-4 w-4" />
        </button>
        <div className="h-3.5 w-px bg-divider" />
        <button onClick={navigateForward} className="p-1.5 text-text-secondary hover:text-text-primary">
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>

      {/* Title */}
      <h2 className="text-sm font-semibold text-text-primary">{title}</h2>

      {/* Today */}
      <button
        onClick={goToToday}
        className="rounded-md bg-surface-secondary px-2.5 py-1 text-xs font-medium text-accent hover:bg-accent-light"
      >
        Today
      </button>

      <div className="flex-1" />

      {/* View Mode Picker */}
      <div className="flex gap-0.5 rounded-lg bg-surface-secondary p-0.5">
        {VIEW_MODES.map(({ mode, label }) => (
          <button
            key={mode}
            onClick={() => setViewMode(mode)}
            className={`rounded-md px-2 py-1 text-xs font-medium transition ${
              viewMode === mode
                ? 'bg-accent text-on-accent'
                : 'text-text-tertiary hover:text-text-primary'
            }`}
          >
            {label}
          </button>
        ))}
      </div>
    </div>
  )
}
