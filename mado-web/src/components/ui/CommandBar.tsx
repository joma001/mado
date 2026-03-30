'use client'

import { useEffect, useRef, useState, useCallback } from 'react'
import {
  Calendar,
  CheckSquare,
  CalendarDays,
  AlignJustify,
  Clock,
  FileText,
  Plus,
  ArrowRight,
} from 'lucide-react'
import { useCalendarStore } from '@/stores/calendarStore'
import type { CalendarViewMode } from '@/types/calendar'

interface ParsedInput {
  title: string
  date: Date | null
  time: string | null
}

function parseNaturalDate(input: string): ParsedInput {
  const now = new Date()
  let title = input
  let date: Date | null = null
  let time: string | null = null

  // Time detection
  const timePatterns = [
    { re: /(\d{1,2}):(\d{2})\s*(am|pm)?/i, extract: (m: RegExpMatchArray) => {
      let h = parseInt(m[1])
      const min = m[2]
      if (m[3]) {
        if (m[3].toLowerCase() === 'pm' && h < 12) h += 12
        if (m[3].toLowerCase() === 'am' && h === 12) h = 0
      }
      return `${String(h).padStart(2, '0')}:${min}`
    }},
    { re: /(\d{1,2})\s*(pm|am)/i, extract: (m: RegExpMatchArray) => {
      let h = parseInt(m[1])
      if (m[2].toLowerCase() === 'pm' && h < 12) h += 12
      if (m[2].toLowerCase() === 'am' && h === 12) h = 0
      return `${String(h).padStart(2, '0')}:00`
    }},
    // Korean: 오후 3시, 오전 10시
    { re: /오후\s*(\d{1,2})시/, extract: (m: RegExpMatchArray) => {
      let h = parseInt(m[1])
      if (h < 12) h += 12
      return `${String(h).padStart(2, '0')}:00`
    }},
    { re: /오전\s*(\d{1,2})시/, extract: (m: RegExpMatchArray) => {
      const h = parseInt(m[1]) % 12
      return `${String(h).padStart(2, '0')}:00`
    }},
  ]

  for (const { re, extract } of timePatterns) {
    const m = input.match(re)
    if (m) {
      time = extract(m)
      title = title.replace(m[0], '').trim()
      break
    }
  }

  // Date detection
  const tomorrow = new Date(now)
  tomorrow.setDate(now.getDate() + 1)

  if (/tomorrow|내일/i.test(input)) {
    date = tomorrow
    title = title.replace(/tomorrow|내일/gi, '').trim()
  } else if (/next monday|다음주 월요일?/i.test(input)) {
    const d = new Date(now)
    const day = d.getDay()
    d.setDate(d.getDate() + ((8 - day) % 7 || 7))
    date = d
    title = title.replace(/next monday|다음주 월요일?/gi, '').trim()
  } else if (/next week|다음주/i.test(input)) {
    const d = new Date(now)
    d.setDate(d.getDate() + 7)
    date = d
    title = title.replace(/next week|다음주/gi, '').trim()
  } else if (/today|오늘/i.test(input)) {
    date = now
    title = title.replace(/today|오늘/gi, '').trim()
  }

  // Clean up extra spaces and punctuation
  title = title.replace(/\s{2,}/g, ' ').replace(/^[,\s]+|[,\s]+$/g, '').trim()

  return { title: title || input, date, time }
}

function formatDate(date: Date): string {
  const today = new Date()
  const tomorrow = new Date(today)
  tomorrow.setDate(today.getDate() + 1)

  if (date.toDateString() === today.toDateString()) return 'Today'
  if (date.toDateString() === tomorrow.toDateString()) return 'Tomorrow'

  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

interface CommandBarProps {
  open: boolean
  onClose: () => void
}

type ActionItem =
  | { kind: 'new-task'; title: string; date: Date | null }
  | { kind: 'new-event'; title: string; date: Date | null; time: string | null }
  | { kind: 'go-to-today' }
  | { kind: 'view-monthly' }
  | { kind: 'view-weekly' }
  | { kind: 'view-daily' }
  | { kind: 'new-daily-note' }

const QUICK_ACTIONS: Array<{ item: ActionItem; label: string; shortcut: string; icon: React.FC<{ className?: string }> }> = [
  { item: { kind: 'go-to-today' }, label: 'Go to Today', shortcut: 'T', icon: Calendar },
  { item: { kind: 'view-monthly' }, label: 'Monthly View', shortcut: 'M', icon: CalendarDays },
  { item: { kind: 'view-weekly' }, label: 'Weekly View', shortcut: 'W', icon: AlignJustify },
  { item: { kind: 'view-daily' }, label: 'Daily View', shortcut: 'D', icon: Clock },
  { item: { kind: 'new-daily-note' }, label: 'New Daily Note', shortcut: '⌘D', icon: FileText },
]

export function CommandBar({ open, onClose }: CommandBarProps) {
  const [query, setQuery] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const setViewMode = useCalendarStore((s) => s.setViewMode)
  const goToToday = useCalendarStore((s) => s.goToToday)

  useEffect(() => {
    if (open) {
      setQuery('')
      setSelectedIndex(0)
      setTimeout(() => inputRef.current?.focus(), 0)
    }
  }, [open])

  const parsed = query.trim() ? parseNaturalDate(query) : null

  const inputItems: ActionItem[] = parsed
    ? [
        { kind: 'new-task', title: parsed.title, date: parsed.date },
        { kind: 'new-event', title: parsed.title, date: parsed.date, time: parsed.time },
      ]
    : []

  const displayItems = query.trim()
    ? inputItems
    : QUICK_ACTIONS.map((a) => a.item)

  const execute = useCallback(async (item: ActionItem) => {
    onClose()
    switch (item.kind) {
      case 'go-to-today':
        goToToday()
        break
      case 'view-monthly':
        setViewMode('monthly' as CalendarViewMode)
        break
      case 'view-weekly':
        setViewMode('weekly' as CalendarViewMode)
        break
      case 'view-daily':
        setViewMode('daily' as CalendarViewMode)
        break
      case 'new-daily-note':
        // Future: open daily note editor
        break
      case 'new-task': {
        const body: Record<string, string> = { title: item.title }
        if (item.date) body.due = item.date.toISOString().split('T')[0] + 'T00:00:00.000Z'
        await fetch('/api/google/tasks', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
        break
      }
      case 'new-event': {
        const start = item.date ?? new Date()
        const startISO = item.time
          ? new Date(`${start.toISOString().split('T')[0]}T${item.time}:00`).toISOString()
          : start.toISOString().split('T')[0]
        const end = item.time
          ? new Date(new Date(`${start.toISOString().split('T')[0]}T${item.time}:00`).getTime() + 3600000).toISOString()
          : start.toISOString().split('T')[0]
        await fetch('/api/google/calendar', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            summary: item.title,
            start: item.time ? { dateTime: startISO } : { date: startISO },
            end: item.time ? { dateTime: end } : { date: end },
          }),
        })
        break
      }
    }
  }, [goToToday, setViewMode, onClose])

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') { onClose(); return }
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setSelectedIndex((i) => Math.min(i + 1, displayItems.length - 1))
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setSelectedIndex((i) => Math.max(i - 1, 0))
    } else if (e.key === 'Enter') {
      e.preventDefault()
      if (displayItems[selectedIndex]) execute(displayItems[selectedIndex])
    }
  }, [displayItems, selectedIndex, execute, onClose])

  useEffect(() => {
    setSelectedIndex(0)
  }, [query])

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center pt-[20vh]"
      onClick={onClose}
    >
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/30 backdrop-blur-sm" />

      {/* Panel */}
      <div
        className="relative w-[560px] rounded-xl border border-border bg-surface shadow-2xl"
        onClick={(e) => e.stopPropagation()}
        onKeyDown={handleKeyDown}
      >
        {/* Input */}
        <div className="flex items-center gap-3 border-b border-border px-4 py-3">
          <Plus className="h-4 w-4 shrink-0 text-text-tertiary" />
          <input
            ref={inputRef}
            type="text"
            className="flex-1 bg-transparent text-sm text-text-primary placeholder:text-text-placeholder outline-none"
            placeholder="Type a command or create task/event…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <kbd className="text-[10px] bg-surface-secondary border border-border rounded px-1.5 py-0.5 text-text-tertiary">ESC</kbd>
        </div>

        {/* Results */}
        <div className="py-1.5 max-h-[320px] overflow-y-auto">
          {query.trim() ? (
            // Dynamic items: New Task + New Event
            <>
              {parsed && (
                <>
                  {/* New Task row */}
                  <button
                    className={`w-full flex items-center gap-3 px-4 py-2.5 text-left transition ${
                      selectedIndex === 0 ? 'bg-accent-light' : 'hover:bg-hover-bg'
                    }`}
                    onClick={() => execute(inputItems[0])}
                    onMouseEnter={() => setSelectedIndex(0)}
                  >
                    <CheckSquare className="h-4 w-4 shrink-0 text-accent" />
                    <div className="flex-1 min-w-0">
                      <span className="text-sm text-text-primary">New Task: </span>
                      <span className="text-sm font-medium text-text-primary">{parsed.title}</span>
                    </div>
                    {parsed.date && (
                      <span className="text-xs text-text-tertiary shrink-0">{formatDate(parsed.date)}</span>
                    )}
                    <ArrowRight className="h-3.5 w-3.5 text-text-tertiary shrink-0" />
                  </button>

                  {/* New Event row */}
                  <button
                    className={`w-full flex items-center gap-3 px-4 py-2.5 text-left transition ${
                      selectedIndex === 1 ? 'bg-accent-light' : 'hover:bg-hover-bg'
                    }`}
                    onClick={() => execute(inputItems[1])}
                    onMouseEnter={() => setSelectedIndex(1)}
                  >
                    <Calendar className="h-4 w-4 shrink-0 text-accent" />
                    <div className="flex-1 min-w-0">
                      <span className="text-sm text-text-primary">New Event: </span>
                      <span className="text-sm font-medium text-text-primary">{parsed.title}</span>
                    </div>
                    <div className="flex items-center gap-1.5 shrink-0">
                      {parsed.date && (
                        <span className="text-xs text-text-tertiary">{formatDate(parsed.date)}</span>
                      )}
                      {parsed.time && (
                        <span className="text-xs text-text-tertiary">{parsed.time}</span>
                      )}
                    </div>
                    <ArrowRight className="h-3.5 w-3.5 text-text-tertiary shrink-0" />
                  </button>
                </>
              )}
            </>
          ) : (
            // Quick actions
            <div className="px-3">
              <p className="px-1 pb-1 pt-0.5 text-[10px] font-medium uppercase tracking-wide text-text-tertiary">Quick Actions</p>
              {QUICK_ACTIONS.map((action, idx) => {
                const Icon = action.icon
                return (
                  <button
                    key={action.shortcut}
                    className={`w-full flex items-center gap-3 rounded-lg px-3 py-2 text-left transition ${
                      selectedIndex === idx ? 'bg-accent-light' : 'hover:bg-hover-bg'
                    }`}
                    onClick={() => execute(action.item)}
                    onMouseEnter={() => setSelectedIndex(idx)}
                  >
                    <Icon className="h-4 w-4 shrink-0 text-text-secondary" />
                    <span className="flex-1 text-sm text-text-primary">{action.label}</span>
                    <kbd className="text-[10px] bg-surface-secondary border border-border rounded px-1.5 py-0.5 text-text-tertiary">
                      {action.shortcut}
                    </kbd>
                  </button>
                )
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
