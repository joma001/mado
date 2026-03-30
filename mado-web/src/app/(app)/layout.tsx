'use client'

import { useSession } from 'next-auth/react'
import { redirect } from 'next/navigation'
import { useEffect } from 'react'
import { Sidebar } from '@/components/layout/Sidebar'
import { useCalendarStore } from '@/stores/calendarStore'
import { useSettingsStore } from '@/stores/settingsStore'

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const { status } = useSession()
  const fetchCalendars = useCalendarStore((s) => s.fetchCalendars)
  const fetchCalendarPrefs = useCalendarStore((s) => s.fetchCalendarPrefs)
  const fetchSettings = useSettingsStore((s) => s.fetchSettings)

  useEffect(() => {
    if (status === 'authenticated') {
      fetchCalendars()
      fetchCalendarPrefs()
      fetchSettings()
    }
  }, [status, fetchCalendars, fetchCalendarPrefs, fetchSettings])

  if (status === 'loading') {
    return (
      <div className="flex min-h-screen items-center justify-center bg-surface">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
      </div>
    )
  }

  if (status === 'unauthenticated') {
    redirect('/login')
  }

  return (
    <div className="flex h-screen bg-surface">
      <Sidebar />
      <main className="flex-1 overflow-hidden">{children}</main>
    </div>
  )
}
