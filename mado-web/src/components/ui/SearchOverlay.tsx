'use client'

import { useEffect, useRef, useState, useMemo } from 'react'
import { Search, Calendar, CheckSquare, FileText, X } from 'lucide-react'
import { useCalendarStore } from '@/stores/calendarStore'
import { useTaskStore } from '@/stores/taskStore'
import { format } from 'date-fns'

interface SearchResult {
  id: string
  type: 'event' | 'task' | 'note'
  title: string
  snippet?: string
  time?: string
}

interface SearchOverlayProps {
  open: boolean
  onClose: () => void
}

const TYPE_LABELS: Record<SearchResult['type'], string> = {
  event: 'Event',
  task: 'Task',
  note: 'Note',
}

const TYPE_COLORS: Record<SearchResult['type'], string> = {
  event: 'text-accent bg-accent-light',
  task: 'text-priority-medium bg-orange-50',
  note: 'text-text-secondary bg-surface-secondary',
}

function highlight(text: string, query: string): string {
  if (!query) return text
  return text
}

function matchesQuery(text: string | undefined, q: string): boolean {
  if (!text) return false
  return text.toLowerCase().includes(q.toLowerCase())
}

export function SearchOverlay({ open, onClose }: SearchOverlayProps) {
  const [query, setQuery] = useState('')
  const inputRef = useRef<HTMLInputElement>(null)
  const events = useCalendarStore((s) => s.events)
  const tasks = useTaskStore((s) => s.tasks)

  useEffect(() => {
    if (open) {
      setQuery('')
      setTimeout(() => inputRef.current?.focus(), 0)
    }
  }, [open])

  const results = useMemo<SearchResult[]>(() => {
    if (!query.trim()) return []
    const q = query.trim()

    const eventResults: SearchResult[] = events
      .filter((e) => matchesQuery(e.title, q) || matchesQuery(e.location, q) || matchesQuery(e.notes, q))
      .slice(0, 8)
      .map((e) => ({
        id: e.id,
        type: 'event',
        title: e.title,
        snippet: e.location ?? e.notes?.slice(0, 60),
        time: e.isAllDay
          ? format(new Date(e.startDate), 'MMM d')
          : format(new Date(e.startDate), 'MMM d, h:mm a'),
      }))

    const taskResults: SearchResult[] = tasks
      .filter((t) => matchesQuery(t.title, q) || matchesQuery(t.notes, q))
      .slice(0, 8)
      .map((t) => ({
        id: t.id,
        type: 'task',
        title: t.title,
        snippet: t.notes?.slice(0, 60),
        time: t.dueDate ? format(new Date(t.dueDate), 'MMM d') : undefined,
      }))

    return [...eventResults, ...taskResults]
  }, [query, events, tasks])

  // Group results by type
  const grouped = useMemo(() => {
    const map: Partial<Record<SearchResult['type'], SearchResult[]>> = {}
    for (const r of results) {
      if (!map[r.type]) map[r.type] = []
      map[r.type]!.push(r)
    }
    return map
  }, [results])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') onClose()
  }

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col items-stretch"
      onClick={onClose}
    >
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/30 backdrop-blur-sm" />

      {/* Panel — positioned at top */}
      <div
        className="relative mx-4 mt-4 rounded-xl border border-border bg-surface shadow-lg max-h-[60vh] flex flex-col overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Search input */}
        <div className="flex items-center gap-3 border-b border-border px-4 py-3 shrink-0">
          <Search className="h-4 w-4 shrink-0 text-text-tertiary" />
          <input
            ref={inputRef}
            type="text"
            className="flex-1 bg-transparent text-sm text-text-primary placeholder:text-text-placeholder outline-none"
            placeholder="Search events, tasks, notes…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
          />
          {query && (
            <button onClick={() => setQuery('')} className="text-text-tertiary hover:text-text-secondary transition">
              <X className="h-4 w-4" />
            </button>
          )}
          <kbd className="text-[10px] bg-surface-secondary border border-border rounded px-1.5 py-0.5 text-text-tertiary shrink-0">ESC</kbd>
        </div>

        {/* Results */}
        <div className="overflow-y-auto flex-1">
          {query.trim() && results.length === 0 && (
            <div className="px-4 py-8 text-center text-sm text-text-tertiary">
              No results for &ldquo;{query}&rdquo;
            </div>
          )}

          {!query.trim() && (
            <div className="px-4 py-8 text-center text-sm text-text-tertiary">
              Type to search across events, tasks, and notes
            </div>
          )}

          {(['event', 'task', 'note'] as SearchResult['type'][]).map((type) => {
            const group = grouped[type]
            if (!group?.length) return null
            const Icon = type === 'event' ? Calendar : type === 'task' ? CheckSquare : FileText
            return (
              <div key={type}>
                <div className="px-4 py-2 flex items-center gap-2">
                  <p className="text-[10px] font-medium uppercase tracking-wide text-text-tertiary">
                    {TYPE_LABELS[type]}s
                  </p>
                </div>
                {group.map((result) => (
                  <button
                    key={result.id}
                    className="w-full flex items-start gap-3 px-4 py-2.5 text-left hover:bg-hover-bg transition"
                    onClick={onClose}
                  >
                    <Icon className="h-4 w-4 shrink-0 mt-0.5 text-text-secondary" />
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-text-primary truncate">
                        {highlight(result.title, query)}
                      </p>
                      {result.snippet && (
                        <p className="text-xs text-text-tertiary truncate mt-0.5">
                          {result.snippet}
                        </p>
                      )}
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      {result.time && (
                        <span className="text-xs text-text-tertiary">{result.time}</span>
                      )}
                      <span className={`text-[10px] rounded px-1.5 py-0.5 font-medium ${TYPE_COLORS[result.type]}`}>
                        {TYPE_LABELS[result.type]}
                      </span>
                    </div>
                  </button>
                ))}
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
