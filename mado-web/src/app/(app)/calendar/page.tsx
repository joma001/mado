'use client'

import { useEffect } from 'react'
import { useCalendarStore } from '@/stores/calendarStore'
import { Toolbar } from '@/components/layout/Toolbar'
import { WeeklyView } from '@/components/calendar/WeeklyView'
import { MonthlyView } from '@/components/calendar/MonthlyView'
import { DailyView } from '@/components/calendar/DailyView'

export default function CalendarPage() {
  const { viewMode, fetchEvents, isLoading } = useCalendarStore()

  useEffect(() => {
    fetchEvents()
  }, [fetchEvents])

  return (
    <div className="flex h-full flex-col">
      <Toolbar />
      {isLoading && (
        <div className="flex items-center justify-center py-2">
          <div className="h-4 w-4 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      )}
      {viewMode === 'weekly' && <WeeklyView />}
      {viewMode === 'monthly' && <MonthlyView />}
      {viewMode === 'daily' && <DailyView />}
    </div>
  )
}
