'use client'

import { useState, useEffect } from 'react'
import { format, addHours, parseISO } from 'date-fns'
import { useCalendarStore } from '@/stores/calendarStore'

interface EventCreateFormProps {
  defaultStart?: Date
  onClose: () => void
}

function toDateTimeLocal(date: Date): string {
  return format(date, "yyyy-MM-dd'T'HH:mm")
}

function toDateLocal(date: Date): string {
  return format(date, 'yyyy-MM-dd')
}

export function EventCreateForm({ defaultStart, onClose }: EventCreateFormProps) {
  const { calendars, createEvent } = useCalendarStore()

  const initStart = defaultStart ?? new Date()
  const initEnd = addHours(initStart, 1)

  const [title, setTitle] = useState('')
  const [startStr, setStartStr] = useState(toDateTimeLocal(initStart))
  const [endStr, setEndStr] = useState(toDateTimeLocal(initEnd))
  const [allDay, setAllDay] = useState(false)
  const [allDayStart, setAllDayStart] = useState(toDateLocal(initStart))
  const [allDayEnd, setAllDayEnd] = useState(toDateLocal(initEnd))
  const [location, setLocation] = useState('')
  const [notes, setNotes] = useState('')
  const [guestInput, setGuestInput] = useState('')
  const [addMeet, setAddMeet] = useState(false)
  const [calendarId, setCalendarId] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  // Set default calendarId to primary when calendars load
  useEffect(() => {
    if (!calendarId && calendars.length > 0) {
      const primary = calendars.find((c) => c.primary) ?? calendars[0]
      setCalendarId(primary.id)
    }
  }, [calendars, calendarId])

  async function handleSave() {
    if (!title.trim()) { setError('Title is required.'); return }
    setError('')
    setSaving(true)

    const guests = guestInput
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean)
      .map((email) => ({ email, responseStatus: 'needsAction' as const }))

    const payload = allDay
      ? {
          title: title.trim(),
          startDate: new Date(allDayStart).toISOString(),
          endDate: new Date(allDayEnd).toISOString(),
          isAllDay: true,
          location: location.trim() || undefined,
          notes: notes.trim() || undefined,
          attendees: guests,
          addConferencingIfRequested: addMeet,
        }
      : {
          title: title.trim(),
          startDate: parseISO(startStr).toISOString(),
          endDate: parseISO(endStr).toISOString(),
          isAllDay: false,
          location: location.trim() || undefined,
          notes: notes.trim() || undefined,
          attendees: guests,
          addConferencingIfRequested: addMeet,
        }

    try {
      await createEvent(calendarId || 'primary', payload)
      onClose()
    } catch {
      setError('Failed to create event. Please try again.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={onClose}>
      <div
        className="w-[440px] rounded-xl bg-surface border border-border shadow-2xl flex flex-col max-h-[90vh]"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-divider px-5 py-4">
          <h2 className="text-sm font-semibold text-text-primary">New Event</h2>
          <button
            onClick={onClose}
            className="flex h-7 w-7 items-center justify-center rounded-full text-text-secondary hover:bg-hover-bg transition text-lg leading-none"
            aria-label="Close"
          >
            ×
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4">
          {/* Title */}
          <div>
            <input
              autoFocus
              type="text"
              placeholder="Event title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') handleSave() }}
              className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary placeholder-text-placeholder outline-none focus:border-accent transition"
            />
            {error && <p className="mt-1 text-xs text-error">{error}</p>}
          </div>

          {/* All-day toggle */}
          <div className="flex items-center gap-3">
            <label className="relative inline-flex cursor-pointer items-center gap-2">
              <div
                onClick={() => setAllDay((v) => !v)}
                className={`h-5 w-9 rounded-full transition-colors ${allDay ? 'bg-accent' : 'bg-border'}`}
              >
                <div className={`mt-0.5 ml-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform ${allDay ? 'translate-x-4' : 'translate-x-0'}`} />
              </div>
              <span className="text-sm text-text-secondary">All day</span>
            </label>
          </div>

          {/* Date/time */}
          {allDay ? (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mb-1 block text-xs font-medium text-text-tertiary">Start date</label>
                <input
                  type="date"
                  value={allDayStart}
                  onChange={(e) => setAllDayStart(e.target.value)}
                  className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary outline-none focus:border-accent transition"
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-text-tertiary">End date</label>
                <input
                  type="date"
                  value={allDayEnd}
                  onChange={(e) => setAllDayEnd(e.target.value)}
                  className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary outline-none focus:border-accent transition"
                />
              </div>
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mb-1 block text-xs font-medium text-text-tertiary">Start</label>
                <input
                  type="datetime-local"
                  value={startStr}
                  onChange={(e) => setStartStr(e.target.value)}
                  className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary outline-none focus:border-accent transition"
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-text-tertiary">End</label>
                <input
                  type="datetime-local"
                  value={endStr}
                  onChange={(e) => setEndStr(e.target.value)}
                  className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary outline-none focus:border-accent transition"
                />
              </div>
            </div>
          )}

          {/* Location */}
          <div>
            <label className="mb-1 block text-xs font-medium text-text-tertiary">Location</label>
            <input
              type="text"
              placeholder="Add location"
              value={location}
              onChange={(e) => setLocation(e.target.value)}
              className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary placeholder-text-placeholder outline-none focus:border-accent transition"
            />
          </div>

          {/* Notes */}
          <div>
            <label className="mb-1 block text-xs font-medium text-text-tertiary">Notes</label>
            <textarea
              placeholder="Add notes"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={3}
              className="w-full resize-none rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary placeholder-text-placeholder outline-none focus:border-accent transition"
            />
          </div>

          {/* Guests */}
          <div>
            <label className="mb-1 block text-xs font-medium text-text-tertiary">Guests</label>
            <input
              type="text"
              placeholder="email@example.com, another@example.com"
              value={guestInput}
              onChange={(e) => setGuestInput(e.target.value)}
              className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary placeholder-text-placeholder outline-none focus:border-accent transition"
            />
            <p className="mt-1 text-xs text-text-tertiary">Separate multiple emails with commas</p>
          </div>

          {/* Google Meet */}
          <div className="flex items-center gap-3">
            <label className="relative inline-flex cursor-pointer items-center gap-2">
              <div
                onClick={() => setAddMeet((v) => !v)}
                className={`h-5 w-9 rounded-full transition-colors ${addMeet ? 'bg-accent' : 'bg-border'}`}
              >
                <div className={`mt-0.5 ml-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform ${addMeet ? 'translate-x-4' : 'translate-x-0'}`} />
              </div>
              <span className="text-sm text-text-secondary">Add Google Meet</span>
            </label>
          </div>

          {/* Calendar selector */}
          {calendars.length > 1 && (
            <div>
              <label className="mb-1 block text-xs font-medium text-text-tertiary">Calendar</label>
              <select
                value={calendarId}
                onChange={(e) => setCalendarId(e.target.value)}
                className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-text-primary outline-none focus:border-accent transition"
              >
                {calendars.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.summary}
                  </option>
                ))}
              </select>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex gap-2 border-t border-divider px-5 py-4">
          <button
            onClick={onClose}
            className="flex-1 rounded-md bg-surface-secondary px-4 py-2 text-sm font-medium text-text-primary hover:bg-hover-bg transition"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex-1 rounded-md bg-accent px-4 py-2 text-sm font-medium text-on-accent hover:brightness-95 transition disabled:opacity-60"
          >
            {saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  )
}
