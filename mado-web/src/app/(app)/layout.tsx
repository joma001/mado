'use client'

import { useSession } from 'next-auth/react'
import { redirect } from 'next/navigation'
import { useEffect } from 'react'
import { Sidebar } from '@/components/layout/Sidebar'
import { MobileNav } from '@/components/layout/MobileNav'
import { UndoToast } from '@/components/ui/UndoToast'
import { KeyboardShortcuts } from '@/components/ui/KeyboardShortcuts'
import { useCalendarStore } from '@/stores/calendarStore'
import { useSettingsStore } from '@/stores/settingsStore'
import { useUndoStore } from '@/stores/undoStore'

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const { status } = useSession()
  const fetchCalendars = useCalendarStore((s) => s.fetchCalendars)
  const fetchCalendarPrefs = useCalendarStore((s) => s.fetchCalendarPrefs)
  const fetchSettings = useSettingsStore((s) => s.fetchSettings)
  const undo = useUndoStore((s) => s.undo)
  const redo = useUndoStore((s) => s.redo)

  useEffect(() => {
    if (status === 'authenticated') {
      fetchCalendars()
      fetchCalendarPrefs()
      fetchSettings()
    }
  }, [status, fetchCalendars, fetchCalendarPrefs, fetchSettings])

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.metaKey && e.shiftKey && e.key === 'z') {
        e.preventDefault()
        void redo()
      } else if (e.metaKey && e.key === 'z') {
        e.preventDefault()
        void undo()
      }
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [undo, redo])

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
    <KeyboardShortcuts>
      <div className="flex h-screen bg-surface">
        <Sidebar />
        <main className="flex-1 overflow-hidden pb-14 md:pb-0">{children}</main>
        <MobileNav />
        <UndoToast />
      </div>
    </KeyboardShortcuts>
  )
}
