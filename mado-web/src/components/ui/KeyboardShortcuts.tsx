'use client'

import { useEffect, useState } from 'react'
import { CommandBar } from './CommandBar'
import { SearchOverlay } from './SearchOverlay'
import { useCalendarStore } from '@/stores/calendarStore'
import type { CalendarViewMode } from '@/types/calendar'

export function KeyboardShortcuts({ children }: { children: React.ReactNode }) {
  const [commandBarOpen, setCommandBarOpen] = useState(false)
  const [searchOpen, setSearchOpen] = useState(false)
  const setViewMode = useCalendarStore((s) => s.setViewMode)
  const goToToday = useCalendarStore((s) => s.goToToday)

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement
      const inInput = target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable

      // Cmd+K — command bar
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setSearchOpen(false)
        setCommandBarOpen((o) => !o)
        return
      }

      // Cmd+F — search
      if (e.key === 'f' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setCommandBarOpen(false)
        setSearchOpen((o) => !o)
        return
      }

      // Cmd+D — daily note
      if (e.key === 'd' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        // Future: open daily note
        return
      }

      // Esc — close overlays
      if (e.key === 'Escape') {
        if (commandBarOpen || searchOpen) {
          setCommandBarOpen(false)
          setSearchOpen(false)
        }
        return
      }

      // Single-key shortcuts — only when not in input and no overlay open
      if (inInput || commandBarOpen || searchOpen) return

      switch (e.key) {
        case 't':
        case 'T':
          e.preventDefault()
          goToToday()
          break
        case 'm':
        case 'M':
          e.preventDefault()
          setViewMode('monthly' as CalendarViewMode)
          break
        case 'w':
        case 'W':
          e.preventDefault()
          setViewMode('weekly' as CalendarViewMode)
          break
        case 'd':
        case 'D':
          e.preventDefault()
          setViewMode('daily' as CalendarViewMode)
          break
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [commandBarOpen, searchOpen, setViewMode, goToToday])

  return (
    <>
      {children}
      <CommandBar open={commandBarOpen} onClose={() => setCommandBarOpen(false)} />
      <SearchOverlay open={searchOpen} onClose={() => setSearchOpen(false)} />
    </>
  )
}
